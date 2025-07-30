#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Проверка доступных функций в библиотеке neo
"""

import neo

print("Доступные модули в neo:")
print("=" * 40)

# Проверяем основные модули
modules_to_check = [
    'io', 'core', 'rawio', 'io'
]

for module_name in modules_to_check:
    if hasattr(neo, module_name):
        module = getattr(neo, module_name)
        print(f"\n{module_name}:")
        for attr in dir(module):
            if not attr.startswith('_') and 'heka' in attr.lower():
                print(f"  {attr}")

# Проверяем io модуль более детально
print("\n" + "=" * 40)
print("Проверяем neo.io модуль:")
print("=" * 40)

if hasattr(neo, 'io'):
    io_module = neo.io
    for attr in dir(io_module):
        if not attr.startswith('_'):
            print(f"  {attr}")

# Проверяем rawio модуль
print("\n" + "=" * 40)
print("Проверяем neo.rawio модуль:")
print("=" * 40)

if hasattr(neo, 'rawio'):
    rawio_module = neo.rawio
    for attr in dir(rawio_module):
        if not attr.startswith('_') and 'heka' in attr.lower():
            print(f"  {attr}")

print("\n" + "=" * 40)
print("Попытка найти HekaIO:")
print("=" * 40)

# Попробуем найти HekaIO в разных местах
try:
    from neo.io import HekaIO
    print("✓ Найден neo.io.HekaIO")
except ImportError:
    print("✗ neo.io.HekaIO не найден")

try:
    from neo.rawio import HekaRawIO
    print("✓ Найден neo.rawio.HekaRawIO")
except ImportError:
    print("✗ neo.rawio.HekaRawIO не найден")

# Проверим все доступные IO классы
print("\n" + "=" * 40)
print("Все доступные IO классы:")
print("=" * 40)

if hasattr(neo, 'io'):
    io_module = neo.io
    for attr in dir(io_module):
        if not attr.startswith('_') and attr.endswith('IO'):
            print(f"  {attr}") 