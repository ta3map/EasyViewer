"""
HEKA to UDF Converter Package

Модуль для конвертации данных HEKA (.mat файлы) в универсальный формат данных (UDF).
"""

from .heka_to_udf import load_mat_file, heka_to_udf, detect_heka_format

__version__ = "1.0.0"
__author__ = "EasyViewer Team"

__all__ = [
    'load_mat_file',
    'heka_to_udf', 
    'detect_heka_format'
]
