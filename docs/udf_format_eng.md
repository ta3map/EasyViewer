# Universal Data Format for Neuroscience (UDF) - Python Dictionary

## Data Structure

```python
udf_data = {
    # === MAIN FIELDS ===
    'format_version': '1.0',                    # str - format version
    'format_name': 'UDF',                       # str - format name
    'created': '2024-01-15T10:30:00Z',         # str - creation date ISO 8601
    'created_by': 'EV Converter v2.1',         # str - creation tool
    
    # === METADATA ===
    'metadata': {
        'experiment': {
            'subject_id': 'mouse_001',          # str - subject ID
            'session_id': '2024-01-15_session1', # str - session ID
            'experimenter': 'Dr. Smith',        # str - experimenter
            'description': 'Visual stimulus response in V1', # str - description
            'protocol': 'Visual stimulation v2.1', # str - protocol
            'notes': 'First recording after surgery', # str - notes
            'source_format': 'ZAV'              # str - source file format
        },
        'session': {
            'start_time': '2024-01-15T10:30:00Z', # str - start time ISO 8601
            'duration_seconds': 3600.0,         # float - duration in seconds
            'lab': 'Neural Circuits Lab',       # str - laboratory
            'institution': 'University of Science', # str - institution
            'equipment': '64-channel silicon probe' # str - equipment
        }
    },
    
    # === DATA ===
    'data': {
        # === ELECTRICAL DATA ===
        'electrical': {
            'data': np.array,                   # [time, channels] or [time, channels, sweeps] float32 - all electrical data
            'recChNames': ['Ch1_CA1', 'Ch2_CA3', ...], # list[str] - channel names (1 element = for all channels)
            'recChUnits': ['μV', 'μV', ...],   # list[str] - measurement units (1 element = for all channels)
            'recChTypes': ['LFP', 'LFP', ...], # list[str] - channel types (1 element = for all channels)
            'sampling_rates': [1000.0, 1000.0, ...], # list[float] - sampling frequencies Hz (1 element = for all channels)
            'gains': [1.0, 1.0, ...],          # list[float] - gain coefficients (1 element = for all channels)
            'offsets': [0.0, 0.0, ...],        # list[float] - offsets (1 element = for all channels)
            'locations': ['CA1', 'CA3', ...],  # list[str] - anatomical locations (1 element = for all channels)
            'impedances': [1.2, 1.5, ...],     # list[float] - impedances MΩ (1 element = for all channels)
            'filtering': ['0.1-300 Hz', ...],  # list[str] - filtering (1 element = for all channels)
            'reference': 'ground',              # str - reference
            'ground': 'skull',                  # str - ground
            'montage': 'custom',                # str - montage
            'spikes': {                         # dict - spike data (optional)
                'timestamps': np.array,         # [time] float64 - spike times
                'channels': np.array,           # [channels] uint32 - channel numbers
                'amplitudes': np.array          # [amplitudes] float32 - spike amplitudes
            }
        },
        
        # === STIMULI ===
        'stimuli': {
            'timestamps': np.array,             # [time] float64 - stimulus times
            'types': ['visual', 'auditory', 'tactile', ...], # list[str] - stimulus types
            'values': np.array,                 # [values] float32 - stimulus values
            'descriptions': ['Visual stimulus onset', 'Auditory tone', ...], # list[str] - descriptions
            'metadata': {                       # dict - additional stimulus metadata
                'intensity': [1.0, 0.8, 1.2],  # list[float] - intensities
                'duration': [100.0, 200.0, 150.0], # list[float] - durations ms
                'frequency': [1000.0, 2000.0, 500.0] # list[float] - frequencies Hz
            }
        },
        
        # === VIDEO DATA ===
        'video': {
            'data': np.array,                   # [time, height, width, channels] uint8/uint16
            'fps': 30.0,                        # float - frames per second
            'resolution': [640, 480],           # list[int] - [width, height]
            'format': 'RGB',                    # str - RGB, grayscale, YUV
            'compression': 'H.264',             # str - H.264, H.265, uncompressed
            'codec': 'libx264',                 # str - compression codec
            'bitrate': 5000.0,                  # float - bitrate kbps
            'pixel_size': 0.5,                  # float - pixel size μm (for microscopy)
            'wavelength': 488.0,                # float - wavelength nm (for fluorescence)
            'exposure_time': 100.0,             # float - exposure time ms
            'timestamps': np.array,             # [time] float64 - frame timestamps
            'metadata': {}                      # dict - additional metadata
        },
        
        # === BEHAVIORAL DATA ===
        'behavioral': {
            'position': {
                'data': np.array,               # [time, x, y] float32
                'sampling_rate': 30.0,          # float - sampling frequency Hz
                'unit': 'cm',                   # str - measurement unit
                'coordinate_system': 'arena_center' # str - coordinate system
            },
            'velocity': {
                'data': np.array,               # [time, vx, vy] float32
                'sampling_rate': 30.0,          # float - sampling frequency Hz
                'unit': 'cm/s',                 # str - measurement unit
                'smoothing': 'gaussian_1s'      # str - smoothing
            },
            'events': {
                'timestamps': np.array,         # [time] float64 - event times
                'types': ['stimulus', 'reward', 'lever_press', ...], # list[str] - event types
                'values': np.array,             # [values] float32 - event values
                'descriptions': ['Visual stimulus onset', 'Reward delivery', ...] # list[str] - descriptions
            }
        },
        
        # === OTHER DATA ===
        'other': {
            'temperature': {
                'data': np.array,               # [time, channels] float32
                'sampling_rate': 1.0,           # float - sampling frequency Hz
                'unit': '°C',                   # str - measurement unit
                'channel_names': ['temp1', 'temp2'] # list[str] - channel names
            },
            'pressure': {
                'data': np.array,               # [time, channels] float32
                'sampling_rate': 10.0,          # float - sampling frequency Hz
                'unit': 'Pa',                   # str - measurement unit
                'channel_names': ['press1', 'press2'] # list[str] - channel names
            },
            'custom': {
                'data': np.array,               # [time, channels] float32
                'sampling_rate': 1000.0,        # float - sampling frequency Hz
                'description': 'Custom sensor data', # str - description
                'unit': 'V',                    # str - measurement unit
                'metadata': {}                  # dict - user metadata
            }
        }
    },
    
    # === TEMPORAL EPOCHS ===
    'epochs': {
        'trials': [
            {
                'start_time': 10.5,             # float - start time seconds
                'end_time': 15.2,               # float - end time seconds
                'type': 'stimulus_presentation', # str - epoch type
                'metadata': {                   # dict - additional data
                    'stimulus_id': 1,
                    'orientation': 45,
                    'contrast': 0.8
                }
            }
        ],
        'sleep_stages': [
            {
                'start_time': 0.0,              # float - start time seconds
                'end_time': 1800.0,             # float - end time seconds
                'stage': 'NREM',                # str - sleep stage
                'confidence': 0.95              # float - confidence 0-1
            }
        ]
    },
    
    # === ANALYSIS ===
    'analysis': {
        'power_spectral_density': {
            'data': np.array,                   # [frequencies, channels] float32
            'frequencies': [1, 2, 4, 8, 16, 32, 64, 128, 256], # list[float] - frequencies Hz
            'unit': 'μV²/Hz',                   # str - measurement unit
            'method': 'welch'                   # str - calculation method
        },
        'coherence': {
            'data': np.array,                   # [frequencies, channel_pairs] float32
            'frequencies': [1, 2, 4, 8, 16, 32, 64, 128, 256], # list[float] - frequencies Hz
            'channel_pairs': [[0, 1], [0, 2], [1, 2]], # list[list[int]] - channel pairs
            'method': 'multitaper'              # str - calculation method
        }
    }
}
```

## Channel Types for Electrical Data

- `LFP` - Local Field Potential
- `voltage` - Intracellular potential
- `current` - Intracellular current
- `spike` - Spike data
- `raw` - Raw data
- `eeg` - EEG
- `emg` - EMG
- `ecg` - ECG
- `custom` - Custom data

## Measurement Units

### Electrical Data:
- `μV` - microvolts
- `mV` - millivolts
- `pA` - picoamperes
- `V` - volts
- `units` - dimensionless quantities

### Video:
- `pixel` - pixels
- `μm` - micrometers
- `nm` - nanometers

### Behavior:
- `cm` - centimeters
- `m` - meters
- `cm/s` - centimeters per second
- `m/s` - meters per second

## Usage Examples

```python
# Creating UDF data
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

# Saving to HDF5
save_udf_to_hdf5(udf_data, 'experiment.udf')

# Loading from HDF5
udf_data = load_udf_from_hdf5('experiment.udf')
```

## Format Principles

1. **Optional Fields** - all fields are optional
2. **Flexibility** - can store different data types
3. **Simplicity** - structure is clear and readable
4. **Compatibility** - works with analysis tools
5. **Performance** - efficient storage in HDF5
6. **Extensibility** - can add custom sections

