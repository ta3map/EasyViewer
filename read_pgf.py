#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для чтения PGF файлов (Heka Pulse Generator File)
"""

import sys
import os
import json
from pathlib import Path

try:
    from neo.io import StimfitIO
except ImportError:
    print("Ошибка: не удалось импортировать StimfitIO из neo.io!")
    print("Убедитесь что установлена библиотека neo: pip install neo")
    sys.exit(1)

def read_pgf_file(pgf_path):
    """
    Читает PGF файл и возвращает его содержимое
    """
    try:
        # Создаем StimfitIO reader
        reader = StimfitIO(filename=pgf_path)
        
        # Читаем данные
        block = reader.read_block()
        
        return block
    except Exception as e:
        print(f"Ошибка при чтении PGF файла: {e}")
        return None

def print_pgf_info(block_data):
    """
    Выводит информацию о содержимом PGF файла
    """
    if block_data is None:
        print("Нет данных для отображения")
        return
    
    print("=" * 60)
    print("СОДЕРЖИМОЕ PGF ФАЙЛА")
    print("=" * 60)
    
    # Основная информация
    print(f"Тип данных: {type(block_data)}")
    
    if hasattr(block_data, '__dict__'):
        print("\nАтрибуты объекта:")
        for attr in dir(block_data):
            if not attr.startswith('_'):
                try:
                    value = getattr(block_data, attr)
                    if callable(value):
                        print(f"  {attr}: <функция>")
                    else:
                        print(f"  {attr}: {value}")
                except:
                    print(f"  {attr}: <не удалось прочитать>")
    
    # Если это Block объект neo
    if hasattr(block_data, 'segments'):
        print(f"\nКоличество сегментов: {len(block_data.segments)}")
        
        for i, segment in enumerate(block_data.segments):
            print(f"\nСегмент {i}:")
            print(f"  Имя: {segment.name}")
            print(f"  Описание: {segment.description}")
            print(f"  Аннотации: {segment.annotations}")
            
            # Сигналы
            if hasattr(segment, 'analogsignals') and segment.analogsignals:
                print(f"  Аналоговые сигналы: {len(segment.analogsignals)}")
                for j, signal in enumerate(segment.analogsignals):
                    print(f"    Сигнал {j}: {signal.shape}, {signal.units}")
            
            # Спайки
            if hasattr(segment, 'spiketrains') and segment.spiketrains:
                print(f"  Спайк-трейны: {len(segment.spiketrains)}")
                for j, spiketrain in enumerate(segment.spiketrains):
                    print(f"    Спайк-трейн {j}: {len(spiketrain)} спайков")
            
            # События
            if hasattr(segment, 'events') and segment.events:
                print(f"  События: {len(segment.events)}")
                for j, event in enumerate(segment.events):
                    print(f"    Событие {j}: {len(event)} событий")
    
    print("\n" + "=" * 60)

def save_pgf_info(block_data, output_path):
    """
    Сохраняет информацию о PGF в JSON файл
    """
    try:
        # Преобразуем данные в JSON-совместимый формат
        def convert_for_json(obj):
            if hasattr(obj, '__dict__'):
                result = {}
                for k, v in obj.__dict__.items():
                    if not k.startswith('_'):
                        result[k] = convert_for_json(v)
                return result
            elif isinstance(obj, (list, tuple)):
                return [convert_for_json(item) for item in obj]
            elif isinstance(obj, dict):
                return {k: convert_for_json(v) for k, v in obj.items()}
            else:
                return str(obj)
        
        json_data = convert_for_json(block_data)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(json_data, f, indent=2, ensure_ascii=False)
        
        print(f"Информация сохранена в: {output_path}")
        
    except Exception as e:
        print(f"Ошибка при сохранении в JSON: {e}")

def main():
    """
    Основная функция
    """
    # Путь к PGF файлу
    pgf_path = "Heka/EC_FS_PYR.pgf"
    
    # Проверяем существование файла
    if not os.path.exists(pgf_path):
        print(f"Файл не найден: {pgf_path}")
        print("Убедитесь, что файл существует в указанном пути")
        return
    
    print(f"Читаем PGF файл: {pgf_path}")
    print(f"Размер файла: {os.path.getsize(pgf_path)} байт")
    
    # Читаем PGF файл
    block_data = read_pgf_file(pgf_path)
    
    # Выводим информацию
    print_pgf_info(block_data)
    
    # Сохраняем в JSON для дальнейшего анализа
    output_path = "pgf_info.json"
    save_pgf_info(block_data, output_path)

if __name__ == "__main__":
    main() 