# Signal Processing

The program provides various signal processing methods to improve data quality and extract components of interest.

## Filtering

Signal filtering allows extraction of frequency components of interest.

**Opening:** Menu **Options/Filtering** in Signal Viewer

### Channel Selection

The left panel contains a list of all channels with checkboxes. Select channels to which filtering will be applied.

**Select ALL** and **Deselect ALL** buttons control selection of all channels.

![Channel selection for filtering](screenshots/filtering_channels.png)

### Filter Types

The **Filter Type** dropdown allows selection of filter type:

- **bandpass** - bandpass filter (passes frequencies in specified range)
- **lowpass** - lowpass filter (passes frequencies below specified)
- **highpass** - highpass filter (passes frequencies above specified)

### Filter Parameters

- **Lower Frequency** - lower frequency limit (Hz)
- **Upper Frequency** - upper frequency limit (Hz)
- **Filter Order** - filter order (determines slope steepness)

![Filter parameters](screenshots/filtering_params.png)

### Preview

The **Check Filtration** button shows the filter frequency response on the graph at the bottom of the window. This allows evaluating the filtering effect before application.

![Filter frequency response](screenshots/filtering_response.png)

### Application

The **Apply** button applies filtering to selected channels. The **Cancel** button cancels changes.

## Mean Subtraction

Mean subtraction helps eliminate background noise common to all channels.

**Opening:** Menu **Options/Average subtraction** in Signal Viewer

### Channel Selection

The left panel contains a list of channels with checkboxes. Select channels that will participate in mean value calculation.

The mean value is calculated across all selected channels and subtracted from each channel.

**Select ALL** and **Deselect ALL** buttons control channel selection.

![Mean subtraction](screenshots/average_subtraction.png)

### Application

The **Apply** button applies mean subtraction to selected channels.

## CSD (Current Source Density)

CSD visualizes spatial distribution of current sources and sinks.

**Opening:** Menu **View/CSD displaying** or **CSD** checkbox on toolbar in Signal Viewer

### Channel Selection

The left panel contains a list of channels with checkboxes. Select channels that will participate in CSD calculation.

**Select ALL** and **Deselect ALL** buttons control channel selection.

### Visualization Parameters

- **Contrast Coef.** - display contrast coefficient (improves region distinction)
- **Smooth Coef.** - smoothing coefficient (reduces noise)

![CSD settings](screenshots/csd_settings.png)

### Application

The **Apply** button applies CSD settings to selected channels and updates visualization.

## Artifact Removal

Artifact removal excludes a short period immediately after stimulus from display.

**Opening:** Menu **Options/Removal of Artifacts** in Signal Viewer or Signal Analysis

### Parameters

- **Artifact Window (ms)** - size of time window after stimulus that is excluded from display

![Artifact removal](screenshots/artifact_removal.png)

### Application

Settings are applied automatically when the parameter is changed.

## Smoothing

Signal smoothing reduces high-frequency noise.

**Available in:** Signal Analysis

### Enabling Smoothing

The **Enable** checkbox enables or disables signal smoothing.

### Smoothing Parameters

- **Kernel** - smoothing kernel size (number of points)
- **Method**:
  - **Moving** - moving average
  - **Median** - median filter
- **Show Raw** - display original signal together with smoothed

![Smoothing settings](screenshots/smoothing.png)

## Channel Processing Settings

In the channel table on the Signal Viewer side panel, you can control application of processing to each channel:

- **Filter** - application of filtering
- **Averaging** - participation in averaging for mean subtraction
- **CSD** - participation in CSD calculation
- **Baseline** - baseline subtraction

Changes in the table are applied immediately.

![Channel processing settings](screenshots/channel_processing.png)

## Saving Processing Settings

Signal processing settings are saved to the channel settings file (`*_channelSettings.stn`) together with the data file. On next file load, settings are automatically restored.

