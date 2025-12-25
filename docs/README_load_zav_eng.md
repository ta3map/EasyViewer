# Documentation for load_zav_file.m Script

## Description

The `load_zav_file.m` script is designed for loading ZAV files while preserving all functionality from the main signalViewerGUI application. It ensures full compatibility with the original code and can be used standalone or as part of other projects.

## Main Features

- ✅ Loading ZAV files (.mat)
- ✅ Automatic detection and conversion of Heka format
- ✅ Sweep data processing
- ✅ Stimulus extraction
- ✅ Event loading (optional)
- ✅ Channel settings loading (optional)
- ✅ Automatic time parameter configuration
- ✅ Detailed loading process logging

## Syntax

```matlab
[lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata] = load_zav_file(filepath, varargin)
```

## Input Parameters

### Required
- `filepath` - path to .mat file (ZAV or Heka format)

### Optional (varargin)
- `'load_events'` - whether to load events (default `false`)
- `'load_settings'` - whether to load channel settings (default `false`)
- `'auto_set_time_windows'` - automatically set time windows for sweeps (default `true`)
- `'auto_set_fs'` - automatically set newFs based on Fs (default `true`)

## Output Parameters

### Main Data
- `lfp` - LFP data matrix
- `spks` - spike data
- `hd` - recording header
- `zavp` - ZAV parameters
- `lfpVar` - LFP variation
- `chnlGrp` - channel groups

### Time Parameters
- `time` - time axis
- `stims` - stimulus times
- `sweep_info` - sweep information

### Events (if loaded)
- `events` - event times
- `event_comments` - event comments
- `event_amplitudes` - event amplitudes
- `event_channels` - event channels
- `event_widths` - event peak widths
- `event_prominences` - event peak prominences
- `event_metadata` - event metadata

## Usage Examples

### 1. Basic File Loading
```matlab
[lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info] = load_zav_file('data.mat');
```

### 2. Loading with Events
```matlab
[lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, events] = load_zav_file('data.mat', 'load_events', true);
```

### 3. Loading with Channel Settings
```matlab
[lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info, events, event_comments, event_amplitudes, event_channels, event_widths, event_prominences, event_metadata, channelNames, channelEnabled, scalingCoefficients, colorsIn, lineCoefficients, mean_group_ch, csd_avaliable, filter_avaliable, filterSettings] = load_zav_file('data.mat', 'load_events', true, 'load_settings', true);
```

### 4. Disabling Automatic Settings
```matlab
[lfp, spks, hd, zavp, lfpVar, chnlGrp, time, stims, sweep_info] = load_zav_file('data.mat', 'auto_set_time_windows', false, 'auto_set_fs', false);
```

## Operation Features

### Automatic Format Detection
The script automatically detects file format:
- If it's Heka format - automatically converts to ZAV
- If it's ZAV format - loads directly

### Sweep Processing
- Automatically detects presence of sweeps in data
- Processes data through `sweepProcessData`
- Sets appropriate time parameters

### Time Parameters
- Automatically creates time axis based on sampling frequency
- For sweeps, automatically sets time windows
- Supports manual configuration through parameters

### Stimuli
- Extracts stimuli from `zavp.realStim`
- Supports both data with and without sweeps

## Dependencies

The script uses the following functions from signalViewerGUI:
- `detectHekaFormat` - Heka format detection
- `hekaToZav` - Heka to ZAV conversion
- `sweepProcessData` - sweep data processing
- `np_flatten` - array processing

## Error Handling

The script includes built-in error handling:
- File existence check
- Try-catch blocks for loading events and settings
- Warnings when loading old formats
- Default settings creation on errors

## Logging

The script outputs detailed information about the loading process:
- Name of loaded file
- Detected format
- Data parameters (sizes, sampling frequency)
- Sweep and stimulus information
- Final summary

## Compatibility

- Fully compatible with signalViewerGUI v1.12.04
- Supports old and new channel settings formats
- Backward compatibility with event formats
- Works with data with and without sweeps

## Files

- `load_zav_file.m` - main loading script
- `example_load_zav.m` - usage examples
- `README_load_zav_eng.md` - this documentation

## Notes

1. The script creates temporary variables that do not conflict with signalViewerGUI global variables
2. All signalViewerGUI functions must be available in the current MATLAB path
3. When loading channel settings, variables are created that can be used for further work
4. The script automatically handles various data loading scenarios

