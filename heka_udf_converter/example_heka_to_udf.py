#!/usr/bin/env python3
"""
Пример использования модуля heka_to_udf для конвертации HEKA файлов в UDF формат
"""

import numpy as np
import h5py
from heka_to_udf import load_mat_file, heka_to_udf


def save_udf_to_hdf5(udf_data: dict, output_path: str):
    """
    Сохраняет UDF данные в HDF5 файл.
    """
    with h5py.File(output_path, 'w') as f:
        # Сохраняем основные поля
        f.attrs['format_version'] = udf_data['format_version']
        f.attrs['format_name'] = udf_data['format_name']
        f.attrs['created'] = udf_data['created']
        f.attrs['created_by'] = udf_data['created_by']
        
        # Создаем группы для метаданных
        metadata_group = f.create_group('metadata')
        experiment_group = metadata_group.create_group('experiment')
        session_group = metadata_group.create_group('session')
        
        # Сохраняем метаданные эксперимента
        for key, value in udf_data['metadata']['experiment'].items():
            experiment_group.attrs[key] = value
        
        # Сохраняем метаданные сессии
        for key, value in udf_data['metadata']['session'].items():
            session_group.attrs[key] = value
        
        # Создаем группу для данных
        data_group = f.create_group('data')
        electrical_group = data_group.create_group('electrical')
        
        # Сохраняем электроданные (только то, что есть)
        electrical_group.create_dataset('data', data=udf_data['data']['electrical']['data'])
        electrical_group.attrs['recChNames'] = udf_data['data']['electrical']['recChNames']
        electrical_group.attrs['recChUnits'] = udf_data['data']['electrical']['recChUnits']
        electrical_group.attrs['sampling_rates'] = udf_data['data']['electrical']['sampling_rates']


def main():
    """
    Пример конвертации HEKA файла в UDF.
    """
    # Путь к тестовому файлу
    heka_file_path = r"\\10.167.11.29\data2\Alina\EC_PYR_FS\01.07.25_P15\Slice1\pyr1\CC_volt_69v_-70mV.mat"
    
    print("=== КОНВЕРТЕР HEKA → UDF ===")
    print(f"Исходный файл: {heka_file_path}")
    
    try:
        # Загружаем MAT файл
        print("\n1. Загрузка MAT файла...")
        mat_data = load_mat_file(heka_file_path)
        print(f"✓ Файл загружен. Найдено переменных: {len(mat_data)}")
        
        # Конвертируем в UDF
        print("\n2. Конвертация в UDF...")
        udf_data = heka_to_udf(mat_data, heka_file_path)
        print("✓ Конвертация завершена")
        
        # Выводим информацию о данных
        electrical_data = udf_data['data']['electrical']
        print(f"\n=== ИНФОРМАЦИЯ О ДАННЫХ ===")
        print(f"Размер данных: {electrical_data['data'].shape}")
        print(f"Количество каналов: {len(electrical_data['recChNames'])}")
        print(f"Имена каналов: {electrical_data['recChNames']}")
        print(f"Единицы измерения: {electrical_data['recChUnits']}")
        print(f"Частота дискретизации: {electrical_data['sampling_rates'][0]:.1f} Гц")
        print(f"Длительность записи: {udf_data['metadata']['session']['duration_seconds']:.2f} с")
        
        # Сохраняем в UDF файл
        output_path = "converted_data.udf"
        print(f"\n3. Сохранение в UDF файл: {output_path}")
        save_udf_to_hdf5(udf_data, output_path)
        print("✓ UDF файл сохранен")
        
        print(f"\n=== КОНВЕРТАЦИЯ ЗАВЕРШЕНА ===")
        print(f"Результат: {output_path}")
        
    except Exception as e:
        print(f"\n✗ Ошибка: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
