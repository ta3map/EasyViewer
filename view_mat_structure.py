#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для просмотра структуры MAT файла
Использует scipy.io для чтения MAT файлов
"""

import scipy.io
import numpy as np
import os
import sys
from pathlib import Path

def print_mat_structure(mat_file_path):
    """
    Выводит структуру MAT файла
    
    Args:
        mat_file_path (str): Путь к MAT файлу
    """
    try:
        # Загружаем MAT файл
        print(f"Загружаем файл: {mat_file_path}")
        mat_data = scipy.io.loadmat(mat_file_path)
        
        print("\n" + "="*60)
        print("СТРУКТУРА MAT ФАЙЛА")
        print("="*60)
        
        # Выводим все переменные в файле
        print(f"\nПеременные в файле ({len(mat_data)} элементов):")
        print("-" * 40)
        
        for key, value in mat_data.items():
            # Пропускаем служебные переменные MATLAB
            if key.startswith('__'):
                continue
                
            print(f"\nПеременная: {key}")
            print(f"  Тип: {type(value).__name__}")
            
            if isinstance(value, np.ndarray):
                print(f"  Размер: {value.shape}")
                print(f"  Тип данных: {value.dtype}")
                
                # Если это структура (структурированный массив)
                if value.dtype.names is not None:
                    print(f"  Поля структуры: {value.dtype.names}")
                    if len(value) > 0:
                        print("  Пример первого элемента:")
                        for field_name in value.dtype.names:
                            field_value = value[0][field_name]
                            if isinstance(field_value, np.ndarray):
                                print(f"    {field_name}: {type(field_value).__name__}, размер {field_value.shape}")
                            else:
                                print(f"    {field_name}: {field_value}")
                
                # Если это обычный массив, показываем первые элементы
                elif value.size > 0 and value.size <= 10:
                    print(f"  Значения: {value.flatten()}")
                elif value.size > 10:
                    print(f"  Первые 5 элементов: {value.flatten()[:5]}")
                    print(f"  Последние 5 элементов: {value.flatten()[-5:]}")
                    
            elif isinstance(value, str):
                print(f"  Значение: {value}")
            else:
                print(f"  Значение: {value}")
        
        # Дополнительная информация о файле
        print("\n" + "="*60)
        print("ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ")
        print("="*60)
        
        # Проверяем версию MAT файла
        try:
            with open(mat_file_path, 'rb') as f:
                header = f.read(124)
                if header.startswith(b'MATLAB'):
                    version = header[124-4:124]
                    print(f"Версия MAT файла: {version}")
        except:
            pass
            
        # Размер файла
        file_size = os.path.getsize(mat_file_path)
        print(f"Размер файла: {file_size:,} байт ({file_size/1024:.1f} KB)")
        
    except Exception as e:
        print(f"Ошибка при чтении файла: {e}")
        return False
    
    return True

def main():
    """Основная функция"""
    import argparse
    
    # Создаем парсер аргументов
    parser = argparse.ArgumentParser(
        description='Анализ структуры MAT файла',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры использования:
  python view_mat_structure.py data.mat                          # Указанный файл
  python view_mat_structure.py "path/to/file.mat"                # Файл с пробелами в пути
  python view_mat_structure.py zav_data_example/CC_volt_10V_-70mV.mat
  run_mat_analysis.bat                                           # Интерактивный выбор файла
        """
    )
    
    parser.add_argument(
        'mat_file', 
        nargs='?', 
        default=None,
        help='Путь к MAT файлу'
    )
    
    args = parser.parse_args()
    mat_file_path = args.mat_file
    
    # Если файл не указан, показываем справку
    if mat_file_path is None:
        parser.print_help()
        return
    
    # Проверяем существование файла
    if not os.path.exists(mat_file_path):
        print(f"ОШИБКА: Файл не найден: {mat_file_path}")
        print("Убедитесь, что файл существует и путь указан правильно")
        return
    
    # Выводим структуру файла
    success = print_mat_structure(mat_file_path)
    
    if success:
        print("\n" + "="*60)
        print("АНАЛИЗ ЗАВЕРШЕН")
        print("="*60)

if __name__ == "__main__":
    main() 