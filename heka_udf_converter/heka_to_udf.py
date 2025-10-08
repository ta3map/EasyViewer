#!/usr/bin/env python3
"""
Модуль для конвертации HEKA .mat файлов в UDF формат
"""

import numpy as np
import scipy.io
import h5py
from datetime import datetime
from typing import Dict, Any, Tuple, List


def load_mat_file(filepath: str) -> Dict[str, Any]:
    """
    Загружает MAT файл, автоматически определяя версию (v7.3 или более ранние).
    """
    try:
        # Сначала пробуем scipy.io.loadmat (для версий < 7.3)
        return scipy.io.loadmat(filepath, struct_as_record=False, squeeze_me=True)
    except (NotImplementedError, ValueError) as e:
        if "Please use HDF reader for matlab v7.3 files" in str(e) or "v7.3" in str(e):
            # Это MAT файл v7.3, используем h5py
            return load_mat_v73(filepath)
        else:
            raise


def load_mat_v73(filepath: str) -> Dict[str, Any]:
    """
    Загружает MAT файл версии 7.3 используя h5py.
    """
    data = {}
    with h5py.File(filepath, 'r') as f:
        def extract_data(name, obj):
            if isinstance(obj, h5py.Dataset):
                data[name] = np.array(obj)
        f.visititems(extract_data)
    return data


def detect_heka_format(mat_data: Dict[str, Any]) -> bool:
    """
    Определяет, является ли загруженный MAT файл файлом HEKA.
    """
    # Ищем переменные с паттерном Trace_*_*
    trace_vars = [var for var in mat_data.keys() if var.startswith('Trace_') and '_' in var[6:]]
    return len(trace_vars) > 0


def extract_heka_data(mat_data: Dict[str, Any]) -> Tuple[np.ndarray, float, int, int, int]:
    """
    Извлекает данные из HEKA MAT файла.
    
    Returns:
        data: массив данных [time_points, channels, sweeps]
        sampling_rate: частота дискретизации в Гц
        n_channels: количество каналов
        n_sweeps: количество свипов
        n_points: количество точек на свип
    """
    # Находим все переменные Trace_*_*
    trace_vars = [var for var in mat_data.keys() if var.startswith('Trace_') and '_' in var[6:]]
    
    if not trace_vars:
        raise ValueError("Не найдены переменные Trace_*_* в файле")
    
    # Парсим имена переменных для определения размеров
    sweep_numbers = []
    channel_numbers = []
    
    for var_name in trace_vars:
        parts = var_name.split('_')
        if len(parts) >= 4:
            sweep_num = int(parts[2])
            channel_num = int(parts[3])
            sweep_numbers.append(sweep_num)
            channel_numbers.append(channel_num)
    
    n_sweeps = max(sweep_numbers) if sweep_numbers else 1
    n_channels = max(channel_numbers) if channel_numbers else 1
    
    # Определяем количество точек из первой переменной
    first_var = trace_vars[0]
    trace_data = mat_data[first_var]
    n_points = trace_data.shape[0]
    
    # Создаем массив данных
    data = np.zeros((n_points, n_channels, n_sweeps))
    
    # Заполняем данные
    for var_name in trace_vars:
        parts = var_name.split('_')
        if len(parts) >= 4:
            sweep_num = int(parts[2]) - 1  # индексация с 0
            channel_num = int(parts[3]) - 1  # индексация с 0
            
            trace_data = mat_data[var_name]
            if trace_data.ndim == 2 and trace_data.shape[1] >= 2:
                # Данные в формате [время, амплитуда]
                data[:, channel_num, sweep_num] = trace_data[:, 1]  # берем амплитуду
            else:
                # Данные в одномерном формате
                data[:, channel_num, sweep_num] = trace_data
    
    # Вычисляем частоту дискретизации из временных интервалов
    first_trace = mat_data[trace_vars[0]]
    if first_trace.ndim == 2 and first_trace.shape[1] >= 2:
        time_data = first_trace[:, 0]  # временные метки
        if len(time_data) > 1:
            dt = np.median(np.diff(time_data))
            sampling_rate = 1.0 / dt if dt > 0 else 1000.0
        else:
            sampling_rate = 1000.0
    else:
        sampling_rate = 1000.0  # значение по умолчанию
    
    return data, sampling_rate, n_channels, n_sweeps, n_points


def determine_units(data: np.ndarray) -> List[str]:
    """
    Определяет единицы измерения данных HEKA на основе их амплитуды.
    """
    # Берем данные из первого канала первого свипа для определения единиц
    sample_data = data[:, 0, 0]
    median_val = np.abs(np.median(sample_data))
    
    if median_val > 1e-3 and median_val < 1e-1:
        # Данные в вольтах, оставляем как есть
        unit = 'V'
    elif median_val < 1e-7:
        # Данные в пиковольтах, оставляем как есть
        unit = 'pV'
    else:
        # Данные в милливольтах, оставляем как есть
        unit = 'mV'
    
    # Все каналы имеют одинаковые единицы
    return [unit] * data.shape[1]


def heka_to_udf(mat_data: Dict[str, Any], source_filepath: str = None) -> Dict[str, Any]:
    """
    Конвертирует данные HEKA в формат UDF.
    
    Args:
        mat_data: данные, загруженные из MAT файла
        source_filepath: путь к исходному файлу (опционально)
    
    Returns:
        udf_data: данные в формате UDF
    """
    if not detect_heka_format(mat_data):
        raise ValueError("Файл не является HEKA форматом")
    
    # Извлекаем данные
    data, sampling_rate, n_channels, n_sweeps, n_points = extract_heka_data(mat_data)
    
    # Определяем единицы измерения (без изменения данных)
    units = determine_units(data)
    
    # Создаем имена каналов (только то, что можем определить из данных)
    channel_names = [f'Ch{i+1}' for i in range(n_channels)]
    
    # Вычисляем длительность записи (только то, что можем вычислить)
    duration_seconds = n_points / sampling_rate
    
    # Создаем UDF структуру с минимальными данными
    udf_data = {
        'format_version': '1.0',
        'format_name': 'UDF',
        'created': datetime.now().isoformat() + 'Z',
        'created_by': 'HEKA to UDF Converter v1.0',
        
        'metadata': {
            'experiment': {
                'source_format': 'HEKA',
                'source_file': source_filepath or 'unknown'
            },
            'session': {
                'duration_seconds': duration_seconds
            }
        },
        
        'data': {
            'electrical': {
                'data': data,  # [time, channels, sweeps] - данные без изменений
                'recChNames': channel_names,
                'recChUnits': units,
                'sampling_rates': [sampling_rate] * n_channels
            }
        }
    }
    
    return udf_data
