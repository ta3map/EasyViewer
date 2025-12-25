# Data Conversion

The program supports conversion of data from various formats to ZAV (.mat) format.

## Available Formats

### Neuralynx (NLX) to ZAV

Conversion of Neuralynx (.nlx) files to ZAV format.

**Opening:** Menu **File/Import** → select **NLX** or **File/convert NLX to ZAV**

**Conversion parameters:**

- **Select Record Path** - select folder with Neuralynx files
- **Detect MUA** - enable multi-unit activity detection
- **threshold (n*STD)** - MUA detection threshold in standard deviation units
- **all channels** / **specific channels** - channel selection for conversion
- **Fs, Hz** - output data sampling frequency (default 1000 Hz)
- **Resample** - whether to resample data

**Process:** Press **Start Conversion** to begin conversion. Progress is displayed in the window.

![NLX to ZAV conversion](screenshots/placeholder_convert_nlx.png)

### ABF to ZAV

Conversion of Axon Binary Format (.abf) files to ZAV format.

**Opening:** Menu **File/Import** → select **ABF**

**Conversion parameters:**

- **Select ABF File** - select .abf file
- **Select Channels** - channel selection for conversion
- **Fs, Hz** - output data sampling frequency
- **Resample** - whether to resample data

![ABF to ZAV conversion](screenshots/placeholder_convert_abf.png)

### Open Ephys to ZAV

Conversion of Open Ephys files to ZAV format.

**Opening:** Menu **File/Import** → select **Open Ephys**

**Conversion parameters:**

- **Select Record Path** - select folder with Open Ephys files
- **Select Channels** - channel selection for conversion
- **Fs, Hz** - output data sampling frequency
- **Resample** - whether to resample data

![Open Ephys to ZAV conversion](screenshots/placeholder_convert_oep.png)

### LFP Import

Import of LFP data from other formats or direct input.

**Opening:** Menu **File/Import** → select **ZAV (.mat)**

**Import parameters:**

- File selection with data
- Signal parameter configuration (sampling frequency, channels)

![LFP import](screenshots/placeholder_import_lfp.png)

## ZAV Format

ZAV format is a MATLAB .mat file with the following structure:

- **lfp** - signal data array [time × channels × sweeps]
- **time** - time vector
- **Fs** - sampling frequency
- **hd** - header with metadata
- **channelNames** - channel names
- Additional fields depending on data type

Detailed format description: [ZAV Format](Zav_mat_format_eng.md)

## Conversion Settings

### Sampling Frequency

The **Fs, Hz** field determines the output data sampling frequency. If the source frequency differs, resampling is performed.

### Resampling

The **Resample** checkbox enables resampling of data to the specified sampling frequency. If disabled, data is saved with the source frequency.

### Channel Selection

For all formats, selection of specific channels or conversion of all channels is available.

### MUA Detection

For NLX format, multi-unit activity detection is available during conversion:

- **Detect MUA** - enable detection
- **threshold (n*STD)** - threshold in standard deviation units

## Saving Results

Conversion results are saved to .mat files in ZAV format. Files can be immediately opened in Signal Viewer or Signal Analysis.

## Error Handling

When conversion errors occur, an error message is displayed in the window. Check:

- Correctness of source file format
- Availability of all necessary files
- Sufficient disk space
- Correctness of conversion parameters

