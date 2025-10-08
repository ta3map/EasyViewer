# Универсальный формат данных для нейронауки (UDF) - Python словарь

## Структура данных

```python
udf_data = {
    # === ОСНОВНЫЕ ПОЛЯ ===
    'format_version': '1.0',                    # str - версия формата
    'format_name': 'UDF',                       # str - название формата
    'created': '2024-01-15T10:30:00Z',         # str - дата создания ISO 8601
    'created_by': 'EV Converter v2.1',         # str - инструмент создания
    
    # === МЕТАДАННЫЕ ===
    'metadata': {
        'experiment': {
            'subject_id': 'mouse_001',          # str - ID субъекта
            'session_id': '2024-01-15_session1', # str - ID сессии
            'experimenter': 'Dr. Smith',        # str - экспериментатор
            'description': 'Visual stimulus response in V1', # str - описание
            'protocol': 'Visual stimulation v2.1', # str - протокол
            'notes': 'First recording after surgery', # str - заметки
            'source_format': 'ZAV'              # str - исходный формат файла
        },
        'session': {
            'start_time': '2024-01-15T10:30:00Z', # str - время начала ISO 8601
            'duration_seconds': 3600.0,         # float - длительность в секундах
            'lab': 'Neural Circuits Lab',       # str - лаборатория
            'institution': 'University of Science', # str - учреждение
            'equipment': '64-channel silicon probe' # str - оборудование
        }
    },
    
    # === ДАННЫЕ ===
    'data': {
        # === ЭЛЕКТРОДАННЫЕ ===
        'electrical': {
            'data': np.array,                   # [time, channels] или [time, channels, sweeps] float32 - все электроданные
            'recChNames': ['Ch1_CA1', 'Ch2_CA3', ...], # list[str] - имена каналов (1 элемент = для всех каналов)
            'recChUnits': ['μV', 'μV', ...],   # list[str] - единицы измерения (1 элемент = для всех каналов)
            'recChTypes': ['LFP', 'LFP', ...], # list[str] - типы каналов (1 элемент = для всех каналов)
            'sampling_rates': [1000.0, 1000.0, ...], # list[float] - частоты дискретизации Гц (1 элемент = для всех каналов)
            'gains': [1.0, 1.0, ...],          # list[float] - коэффициенты усиления (1 элемент = для всех каналов)
            'offsets': [0.0, 0.0, ...],        # list[float] - смещения (1 элемент = для всех каналов)
            'locations': ['CA1', 'CA3', ...],  # list[str] - анатомические локализации (1 элемент = для всех каналов)
            'impedances': [1.2, 1.5, ...],     # list[float] - импедансы МОм (1 элемент = для всех каналов)
            'filtering': ['0.1-300 Hz', ...],  # list[str] - фильтрация (1 элемент = для всех каналов)
            'reference': 'ground',              # str - референс
            'ground': 'skull',                  # str - заземление
            'montage': 'custom',                # str - монтаж
            'spikes': {                         # dict - спайковые данные (опционально)
                'timestamps': np.array,         # [time] float64 - времена спайков
                'channels': np.array,           # [channels] uint32 - номера каналов
                'amplitudes': np.array          # [amplitudes] float32 - амплитуды спайков
            }
        },
        
        # === СТИМУЛЫ ===
        'stimuli': {
            'timestamps': np.array,             # [time] float64 - времена стимулов
            'types': ['visual', 'auditory', 'tactile', ...], # list[str] - типы стимулов
            'values': np.array,                 # [values] float32 - значения стимулов
            'descriptions': ['Visual stimulus onset', 'Auditory tone', ...], # list[str] - описания
            'metadata': {                       # dict - дополнительные метаданные стимулов
                'intensity': [1.0, 0.8, 1.2],  # list[float] - интенсивности
                'duration': [100.0, 200.0, 150.0], # list[float] - длительности мс
                'frequency': [1000.0, 2000.0, 500.0] # list[float] - частоты Гц
            }
        },
        
        # === ВИДЕО ДАННЫЕ ===
        'video': {
            'data': np.array,                   # [time, height, width, channels] uint8/uint16
            'fps': 30.0,                        # float - кадров в секунду
            'resolution': [640, 480],           # list[int] - [width, height]
            'format': 'RGB',                    # str - RGB, grayscale, YUV
            'compression': 'H.264',             # str - H.264, H.265, uncompressed
            'codec': 'libx264',                 # str - кодек сжатия
            'bitrate': 5000.0,                  # float - битрейт кбит/с
            'pixel_size': 0.5,                  # float - размер пикселя мкм (для микроскопии)
            'wavelength': 488.0,                # float - длина волны нм (для флуоресценции)
            'exposure_time': 100.0,             # float - время экспозиции мс
            'timestamps': np.array,             # [time] float64 - временные метки кадров
            'metadata': {}                      # dict - дополнительные метаданные
        },
        
        # === ПОВЕДЕНЧЕСКИЕ ДАННЫЕ ===
        'behavioral': {
            'position': {
                'data': np.array,               # [time, x, y] float32
                'sampling_rate': 30.0,          # float - частота дискретизации Гц
                'unit': 'cm',                   # str - единица измерения
                'coordinate_system': 'arena_center' # str - система координат
            },
            'velocity': {
                'data': np.array,               # [time, vx, vy] float32
                'sampling_rate': 30.0,          # float - частота дискретизации Гц
                'unit': 'cm/s',                 # str - единица измерения
                'smoothing': 'gaussian_1s'      # str - сглаживание
            },
            'events': {
                'timestamps': np.array,         # [time] float64 - времена событий
                'types': ['stimulus', 'reward', 'lever_press', ...], # list[str] - типы событий
                'values': np.array,             # [values] float32 - значения событий
                'descriptions': ['Visual stimulus onset', 'Reward delivery', ...] # list[str] - описания
            }
        },
        
        # === ДРУГИЕ ДАННЫЕ ===
        'other': {
            'temperature': {
                'data': np.array,               # [time, channels] float32
                'sampling_rate': 1.0,           # float - частота дискретизации Гц
                'unit': '°C',                   # str - единица измерения
                'channel_names': ['temp1', 'temp2'] # list[str] - имена каналов
            },
            'pressure': {
                'data': np.array,               # [time, channels] float32
                'sampling_rate': 10.0,          # float - частота дискретизации Гц
                'unit': 'Pa',                   # str - единица измерения
                'channel_names': ['press1', 'press2'] # list[str] - имена каналов
            },
            'custom': {
                'data': np.array,               # [time, channels] float32
                'sampling_rate': 1000.0,        # float - частота дискретизации Гц
                'description': 'Custom sensor data', # str - описание
                'unit': 'V',                    # str - единица измерения
                'metadata': {}                  # dict - пользовательские метаданные
            }
        }
    },
    
    # === ВРЕМЕННЫЕ ЭПОХИ ===
    'epochs': {
        'trials': [
            {
                'start_time': 10.5,             # float - время начала секунды
                'end_time': 15.2,               # float - время окончания секунды
                'type': 'stimulus_presentation', # str - тип эпохи
                'metadata': {                   # dict - дополнительные данные
                    'stimulus_id': 1,
                    'orientation': 45,
                    'contrast': 0.8
                }
            }
        ],
        'sleep_stages': [
            {
                'start_time': 0.0,              # float - время начала секунды
                'end_time': 1800.0,             # float - время окончания секунды
                'stage': 'NREM',                # str - стадия сна
                'confidence': 0.95              # float - уверенность 0-1
            }
        ]
    },
    
    # === АНАЛИЗ ===
    'analysis': {
        'power_spectral_density': {
            'data': np.array,                   # [frequencies, channels] float32
            'frequencies': [1, 2, 4, 8, 16, 32, 64, 128, 256], # list[float] - частоты Гц
            'unit': 'μV²/Hz',                   # str - единица измерения
            'method': 'welch'                   # str - метод расчета
        },
        'coherence': {
            'data': np.array,                   # [frequencies, channel_pairs] float32
            'frequencies': [1, 2, 4, 8, 16, 32, 64, 128, 256], # list[float] - частоты Гц
            'channel_pairs': [[0, 1], [0, 2], [1, 2]], # list[list[int]] - пары каналов
            'method': 'multitaper'              # str - метод расчета
        }
    }
}
```

## Типы каналов для электроданных

- `LFP` - Local Field Potential
- `voltage` - Внутриклеточный потенциал
- `current` - Внутриклеточный ток
- `spike` - Спайковые данные
- `raw` - Сырые данные
- `eeg` - ЭЭГ
- `emg` - ЭМГ
- `ecg` - ЭКГ
- `custom` - Пользовательские данные

## Единицы измерения

### Электроданные:
- `μV` - микровольты
- `mV` - милливольты
- `pA` - пикоамперы
- `V` - вольты
- `units` - безразмерные величины

### Видео:
- `pixel` - пиксели
- `μm` - микрометры
- `nm` - нанометры

### Поведение:
- `cm` - сантиметры
- `m` - метры
- `cm/s` - сантиметры в секунду
- `m/s` - метры в секунду

## Примеры использования

```python
# Создание UDF данных
udf_data = {
    'format_version': '1.0',
    'format_name': 'UDF',
    'created': '2024-01-15T10:30:00Z',
    'created_by': 'EV Converter v2.1',
    'metadata': {...},
    'data': {
        'electrical': {
            'data': lfp_data,  # np.array [time, channels]
            'recChNames': ['Ch1_CA1', 'Ch2_CA3'],
            'recChUnits': ['μV', 'μV'],
            'recChTypes': ['LFP', 'LFP']
        }
    }
}

# Сохранение в HDF5
save_udf_to_hdf5(udf_data, 'experiment.udf')

# Загрузка из HDF5
udf_data = load_udf_from_hdf5('experiment.udf')
```

## Принципы формата

1. **Опциональные поля** - все поля опциональны
2. **Гибкость** - можно хранить разные типы данных
3. **Простота** - структура понятна и читается
4. **Совместимость** - работает с инструментами анализа
5. **Производительность** - эффективное хранение в HDF5
6. **Расширяемость** - можно добавлять пользовательские разделы


