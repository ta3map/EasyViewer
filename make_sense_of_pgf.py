#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Собирает разрозненные данные PGF в понятные протоколы стимуляции
"""

import sys
import os
import json
import struct
import re

def make_sense_of_pgf(filename):
    """Собирает данные в понятные протоколы"""
    
    with open(filename, 'rb') as f:
        data = f.read()
    
    # Сначала найдем все строки (названия протоколов)
    strings = []
    for match in re.finditer(b'[A-Za-z0-9_\-\+\s]+', data):
        s = match.group().decode('ascii', errors='ignore').strip()
        if len(s) > 2 and not s.isdigit():
            strings.append({'text': s, 'position': match.start()})
    
    # Найдем численные параметры
    float32_values = []
    for i in range(0, len(data) - 4, 4):
        try:
            val = struct.unpack('<f', data[i:i+4])[0]
            if -1000 < val < 1000 and abs(val) > 0.001:
                float32_values.append({'value': val, 'position': i})
        except:
            continue
    
    # Группируем данные в протоколы
    protocols = []
    
    # Ищем протоколы по ключевым словам
    protocol_keywords = {
        'ramp': 'Ramp protocol',
        'step': 'Step protocol', 
        'IV': 'IV curve',
        'Cap': 'Capacitance measurement',
        'firing': 'Firing protocol',
        'test': 'Test protocol'
    }
    
    for string_info in strings:
        text = string_info['text']
        pos = string_info['position']
        
        # Определяем тип протокола
        protocol_type = 'Unknown'
        for keyword, desc in protocol_keywords.items():
            if keyword.lower() in text.lower():
                protocol_type = desc
                break
        
        # Ищем связанные параметры (в пределах 1000 байт)
        related_params = []
        for param in float32_values:
            if abs(param['position'] - pos) < 1000:
                related_params.append(param['value'])
        
        # Фильтруем параметры по типу протокола
        if 'ramp' in text.lower():
            # Для ramp: ищем slope, duration, amplitude
            filtered_params = [p for p in related_params if 0.001 <= abs(p) <= 10]
        elif 'step' in text.lower():
            # Для step: ищем amplitude, duration
            filtered_params = [p for p in related_params if abs(p) >= 0.1]
        elif 'firing' in text.lower():
            # Для firing: ищем current amplitude
            filtered_params = [p for p in related_params if abs(p) >= 10]
        else:
            filtered_params = related_params[:5]  # первые 5 параметров
        
        if filtered_params:
            protocol = {
                'name': text,
                'type': protocol_type,
                'position': pos,
                'parameters': filtered_params[:10],  # максимум 10 параметров
                'description': f"{protocol_type}: {text}"
            }
            protocols.append(protocol)
    
    # Создаем понятный результат
    result = {
        'filename': filename,
        'total_protocols': len(protocols),
        'protocols': protocols,
        'summary': {
            'ramp_protocols': len([p for p in protocols if 'ramp' in p['name'].lower()]),
            'step_protocols': len([p for p in protocols if 'step' in p['name'].lower()]),
            'firing_protocols': len([p for p in protocols if 'firing' in p['name'].lower()]),
            'measurement_protocols': len([p for p in protocols if any(x in p['name'].lower() for x in ['cap', 'test', 'iv'])]),
        }
    }
    
    # Выводим понятный результат
    print(f"=== ПОНЯТНЫЕ ПРОТОКОЛЫ СТИМУЛЯЦИИ ===\n")
    print(f"Файл: {filename}")
    print(f"Всего протоколов: {len(protocols)}\n")
    
    for i, protocol in enumerate(protocols, 1):
        print(f"{i:2d}. {protocol['name']}")
        print(f"    Тип: {protocol['type']}")
        if protocol['parameters']:
            params_str = ", ".join([f"{p:.3f}" for p in protocol['parameters'][:5]])
            print(f"    Параметры: {params_str}")
        print()
    
    # Сохраняем результат
    with open('pgf_protocols_clean.json', 'w') as f:
        json.dump(result, f, indent=2)
    
    print(f"Результат сохранен в: pgf_protocols_clean.json")
    return result

if __name__ == '__main__':
    filename = sys.argv[1] if len(sys.argv) > 1 else 'Heka/EC_FS_PYR.pgf'
    make_sense_of_pgf(filename) 