# Конвертер HEKA → UDF

Простой модуль для преобразования данных HEKA (.mat файлы) в универсальный формат данных (UDF).

## Структура пакета

```
heka_udf_converter/
├── __init__.py              # Инициализация пакета
├── heka_to_udf.py          # Основной модуль конвертации
├── example_heka_to_udf.py  # Пример использования
├── requirements_converter.txt  # Зависимости
└── README_converter.md     # Документация
```

## Установка зависимостей

```bash
pip install -r requirements_converter.txt
```

## Использование

### Базовое использование

```python
from heka_udf_converter import load_mat_file, heka_to_udf

# Загружаем HEKA файл
mat_data = load_mat_file("path/to/heka_file.mat")

# Конвертируем в UDF
udf_data = heka_to_udf(mat_data, "path/to/heka_file.mat")

# Теперь udf_data содержит данные в формате UDF
print(f"Размер данных: {udf_data['data']['electrical']['data'].shape}")
```

### Запуск примера

```bash
cd heka_udf_converter
python example_heka_to_udf.py
```

## Особенности

- **Сохранение свипов**: Данные сохраняются в формате `[time, channels, sweeps]` без распрямления
- **Определение единиц измерения**: Автоматически определяет единицы на основе амплитуды данных
- **Поддержка MAT v7.3**: Автоматически определяет версию MAT файла
- **Минимальные метаданные**: Только необходимые поля для совместимости с UDF

## Структура выходных данных

```python
udf_data = {
    'format_version': '1.0',
    'format_name': 'UDF',
    'created': '2024-01-15T10:30:00Z',
    'created_by': 'HEKA to UDF Converter v1.0',
    
    'metadata': {
        'experiment': {
            'source_format': 'HEKA',
            'source_file': 'path/to/source.mat'
        },
        'session': {
            'duration_seconds': 3600.0  # вычисляется из данных
        }
    },
    
    'data': {
        'electrical': {
            'data': np.array,  # [time, channels, sweeps]
            'recChNames': ['Ch1', 'Ch2', ...],  # генерируется автоматически
            'recChUnits': ['mV', 'mV', ...],  # определяется из масштабирования
            'sampling_rates': [1000.0, 1000.0, ...]  # извлекается из временных интервалов
        }
    }
}
```

## Определение единиц измерения

Конвертер определяет единицы измерения на основе амплитуды данных:

- Если `median(data) > 1e-3` и `< 1e-1` → определяет как 'V' (вольты)
- Если `median(data) < 1e-7` → определяет как 'pV' (пиковольты)
- Иначе определяет как 'mV' (милливольты)

**Важно**: Данные не изменяются, только определяется их единица измерения.

## Требования

- Python 3.7+
- numpy
- scipy
- h5py
