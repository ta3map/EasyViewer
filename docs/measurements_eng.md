# Parameter Measurements

Signal Analysis provides tools for measuring various signal parameters relative to stimuli or events.

## Measurement Parameters

### Slope

Slope (steepness) measures the rate of signal change in a certain range relative to the peak.

**Calculation:**

1. Peak is determined in the specified range (peak range)
2. Percentage of peak amplitude is calculated (Slope Percent)
3. Point on signal rise/fall corresponding to this percentage is found
4. Linear regression between the percentage point and peak is calculated
5. Slope is the regression line slope coefficient

**Parameters:**

- **Slope Percent** - percentage of peak amplitude for calculation (0-100)
- **Peak Range** - peak search range (Peak Start, Peak End)
- **Polarity** - peak polarity (positive/negative)

![Slope measurement](screenshots/measurement_slope.png)

### Peak

Peak - maximum or minimum signal value in the specified range.

**Calculation:**

1. In the Peak Range, an extremum is found (maximum for positive, minimum for negative)
2. Peak time and value are recorded

**Parameters:**

- **Peak Range** - peak search range
- **Polarity** - peak polarity

![Peak measurement](screenshots/measurement_peak.png)

### Onset

Onset - moment of signal change start.

**Calculation methods:**

- **Derivative** - based on signal derivative
- **Threshold** - based on threshold in standard deviation units

**Parameters:**

- **Onset Method** - calculation method (derivative/threshold)
- **Onset Threshold** - threshold for threshold method (in std units)

![Onset measurement](screenshots/measurement_onset.png)

### Baseline

Baseline - mean signal value in the specified range before stimulus.

**Calculation:**

1. In the Baseline Range, mean signal value is calculated
2. This value is used as a reference point for other measurements

**Parameters:**

- **Baseline Range** - range for calculation (Baseline Start, Baseline End)

![Baseline measurement](screenshots/measurement_baseline.png)

## Measurement Configuration

### Channel Selection

The **Channel** dropdown allows selection of a channel for measurement. When the channel is changed, all measurements are recalculated.

### Peak Polarity

The **Polarity** dropdown determines the direction of peak search:

- **Positive** - search for positive peak (maximum)
- **Negative** - search for negative peak (minimum)

### Measurement Ranges

All ranges are specified relative to the current reference point (stimulus, event, or time):

- **Baseline Start/End** - range for baseline calculation
- **Peak Start/End** - range for peak search

Values are entered in selected time units (s, ms, min).

The **★** button next to the field allows selecting a point on the graph with a mouse click.

### Slope Percent

The **Slope Percent** field sets the percentage of peak amplitude used for slope calculation. Value from 0 to 100.

## Results Visualization

### Displaying Measurement Elements

Checkboxes control visibility of elements on the graph:

- **Baseline** - display baseline range and its value
- **Peak** - display peak range, peak marker, and its value
- **Slope** - display slope regression line
- **Onset** - display onset marker and its time

### Current Results Table

The table shows results for the current measurement:

- **Slope** - slope value
- **Peak Time (rel)** - peak time relative to reference point
- **Peak Amplitude** - peak amplitude
- **Onset Time (rel)** - onset time relative to reference point
- **Baseline** - baseline value

## Automatic Measurement

The **Auto Measure All** button automatically measures parameters for all stimuli/events/sweeps:

1. Moves to each stimulus/event/sweep
2. Performs measurement with current settings
3. Adds result to the results table

## Results Table

Measurement results accumulate in the results table. Each row contains:

- **Stimulus** - stimulus/event/sweep number
- **Slope** - slope value
- **Peak Time (rel/abs)** - peak time (relative and absolute)
- **Peak Amplitude** - peak amplitude
- **Peak Value (rel)** - peak value relative to baseline
- **Onset Time (rel/abs)** - onset time (relative and absolute)
- **Peak - Onset** - difference between peak and onset
- **Baseline** - baseline value
- **Channel** - channel number
- **Stim Time** - stimulus/event time
- **Info** - additional information

## Average Values Table

The table shows average values across all measurements in the results table:

- **Slope** - average slope value
- **Peak Time (rel)** - average peak time
- **Peak Amplitude** - average peak amplitude
- **Onset Time (rel)** - average onset time
- **Baseline** - average baseline value
- **Peak - Onset** - average difference between peak and onset

## Mean Trace

The **Av. Trace** button toggles the mean signal display mode across all measurements. In this mode:

- The graph shows the averaged signal
- Measurements are performed relative to the mean signal
- This allows evaluating the typical response and its variability

## Smoothing Before Measurement

Signal smoothing can be enabled to reduce noise influence on measurements:

- **Enable** - enable smoothing
- **Kernel** - smoothing kernel size
- **Method** - smoothing method (Moving/Median)
- **Show Raw** - show original signal

Smoothing is applied before all measurement calculations.

## Measurement Metadata

Each measurement saves metadata:

- Measurement configuration parameters
- Range timestamps
- Calculation method
- Channel and stimulus information

Metadata is available through the **Collect All** button and saved when exporting results.

## Saving Results

Measurement results can be saved:

- To Excel file (button **Save** or **Save As**)
- With metadata (through **Collect All**)
- With automatic re-saving (Hot Resave)

## Navigation During Measurements

When measuring parameters, navigation is available:

- **Previous** and **Next** buttons move to previous/next stimulus/event
- Navigation mode is determined automatically based on loaded data
- Status line shows current navigation mode

