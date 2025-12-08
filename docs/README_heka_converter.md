# HEKA to UDF Converter

Конвертер для преобразования данных HEKA (.mat файлы) в универсальный формат данных (UDF).

## Расположение

Конвертер находится в папке `heka_udf_converter/` и представляет собой отдельный Python пакет.

## Быстрый старт

```bash
# Перейти в папку конвертера
cd heka_udf_converter

# Установить зависимости
pip install -r requirements_converter.txt

# Запустить пример
python example_heka_to_udf.py
```

## Использование в коде

```python
from heka_udf_converter import load_mat_file, heka_to_udf

# Загрузить HEKA файл
mat_data = load_mat_file("path/to/heka_file.mat")

# Конвертировать в UDF
udf_data = heka_to_udf(mat_data, "path/to/heka_file.mat")
```

## Подробная документация

См. [README_converter.md](heka_udf_converter/README_converter.md) для подробной документации.

## Особенности

- ✅ Сохранение свипов в формате `[time, channels, sweeps]`
- ✅ Автоматическое определение единиц измерения
- ✅ Поддержка MAT файлов v7.3 и более ранних версий
- ✅ Минимальные метаданные (только реальные данные)
- ✅ Чистый модульный код
