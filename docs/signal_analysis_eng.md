# Signal Analysis

The analysis window is designed for measuring signal parameters relative to stimuli or events.

![Signal Analysis main window](images/placeholder_signal_analysis_main.png)

## Main Window

The window consists of the following elements:

- **Graphical area** - signal display with measurement markers
- **Measurement settings panel** - parameters for calculating slope, peak, onset, baseline
- **Smoothing panel** - signal smoothing settings
- **Current results table** - results for current measurement
- **Results table** - accumulated measurement results
- **Average values table** - average values across all measurements

## Loading Files

### Loading ZAV File

The **Open File** button opens a ZAV file selection dialog. After loading a file, the signal of the selected channel is displayed.

### Loading EV File

The **Load Events** button opens an EV file selection dialog. LFP data for events and the events themselves are loaded.

### File Manager

The **File Manager** button opens the file manager for working with projects and file groups.

## Measurement Settings

### Channel Selection

The **Channel** dropdown allows selection of a channel for analysis. When the channel is changed, the graph updates automatically.

![Channel selection](images/placeholder_analysis_channel.png)

### Peak Polarity

The **Polarity** dropdown determines the direction of peak search:

- **Positive** - search for positive peak (maximum)
- **Negative** - search for negative peak (minimum)

![Peak polarity](images/placeholder_analysis_polarity.png)

### Slope Percent

The **Slope Percent** field sets the percentage of peak amplitude used for slope calculation. Value from 0 to 100.

### Baseline Range

The **Baseline Start** and **Baseline End** fields define the time range for baseline calculation. Values are specified in selected time units relative to the current reference point.

The **★** button next to the field allows selecting a point on the graph with a mouse click.

![Baseline range](images/placeholder_analysis_baseline.png)

### Peak Range

The **Peak Start** and **Peak End** fields define the time range for peak search. Values are specified in selected time units relative to the current reference point.

The **★** button next to the field allows selecting a point on the graph with a mouse click.

![Peak range](images/placeholder_analysis_peak.png)

### Time Window

The **before** and **after** fields define the size of the time window displayed around the current point. Values are specified in selected time units.

![Time window](images/placeholder_analysis_time_window.png)

## Results Visualization

### Displaying Measurement Elements

Checkboxes in the **Results** section control visibility of elements on the graph:

- **Baseline** - display baseline range
- **Peak** - display peak search range and peak marker
- **Slope** - display slope regression line
- **Onset** - display onset marker

![Results visualization](images/placeholder_analysis_visualization.png)

### Current Results Table

The table shows results for the current measurement:

- **Slope** - slope value
- **Peak Time (rel)** - peak time relative to reference point
- **Peak Amplitude** - peak amplitude
- **Onset Time (rel)** - onset time relative to reference point
- **Baseline** - baseline value

![Current results table](images/placeholder_analysis_current_results.png)

## Signal Smoothing

### Enabling Smoothing

The **Enable** checkbox enables or disables signal smoothing before measurement calculations.

### Smoothing Parameters

- **Kernel** - smoothing kernel size (number of points)
- **Method**:
  - **Moving** - moving average
  - **Median** - median filter
- **Show Raw** - display original signal together with smoothed

![Smoothing settings](images/placeholder_analysis_smoothing.png)

## Navigation

### Navigation Mode

The **Mode** status line shows the current navigation mode:

- **time** - time navigation
- **stimulus** - navigation by stimuli
- **event** - navigation by events
- **sweep** - navigation by sweeps

The mode is determined automatically based on loaded data.

![Navigation mode](images/placeholder_analysis_navigation_mode.png)

### Navigation Buttons

The **◀ Previous** and **Next ▶** buttons move the displayed interval one step backward or forward depending on the navigation mode.

### Automatic Measurement

The **Auto Measure All** button automatically measures parameters for all stimuli/events/sweeps and adds results to the table.

## Working with Results Table

### Adding Result

The **Add** button adds the current measurement to the results table. The result includes all parameters from the current results table and metadata.

### Removing Result

Select a row in the results table and press the **Remove** button to delete the result.

### Replacing Result

Select a row in the results table and press the **Replace** button to replace the result with the current measurement.

### Clearing Table

The **Clear Table** button removes all results from the table.

### Results Table

The table contains the following columns:

- **Stimulus** - stimulus/event/sweep number
- **Slope** - slope value
- **Peak Time (rel)** - peak time relative to reference point
- **Peak Time (abs)** - absolute peak time
- **Peak Amplitude** - peak amplitude
- **Peak Value (rel)** - peak value relative to baseline
- **Onset Time (rel)** - onset time relative to reference point
- **Onset Time (abs)** - absolute onset time
- **Peak - Onset** - difference between peak and onset
- **Baseline** - baseline value
- **Channel** - channel number
- **Stim Time** - stimulus/event time
- **Info** - additional information

![Results table](images/placeholder_analysis_results_table.png)

### Average Values Table

The table shows average values across all measurements in the results table:

- **Slope** - average slope value
- **Peak Time (rel)** - average peak time
- **Peak Amplitude** - average peak amplitude
- **Onset Time (rel)** - average onset time
- **Baseline** - average baseline value
- **Peak - Onset** - average difference between peak and onset

![Average values table](images/placeholder_analysis_average_table.png)

## Mean Trace

The **Av. Trace** button toggles the mean signal display mode across all measurements in the results table. In this mode, the graph shows the averaged signal, and measurements are performed relative to this mean signal.

## Saving and Loading Results

### Saving Results

The **Save** button saves results to an Excel file. If a file was loaded previously, results are saved to the same file. Otherwise, a save path selection dialog opens.

The **Save As** button always opens a path selection dialog to save results to a new file.

### Hot Resave

The **Hot Resave** checkbox enables automatic re-saving of results on each addition or modification of a result. Works only if a file was loaded previously.

![Hot Resave](images/placeholder_analysis_hot_resave.png)

### Loading Results

The **Load** button opens an Excel file selection dialog with results. Loaded results are added to the results table.

The **Results** dropdown shows results from the File Manager database for the current file. Selecting a result loads it into the table.

### Collecting All Metadata

The **Collect All** button collects metadata from all results in the table and saves them in structured form.

## Graph Tools

### Zoom

The **Zoom** button activates zoom mode. Allows selecting an area for zooming.

### Pan

The **Pan** button activates panning mode. Allows moving the graph with the mouse.

### Cursor

The **Cursor** button activates the data cursor. Shows coordinates of a point when clicking on the graph.

### Brush

The **Brush** button activates data selection mode on the graph.

### Home

The **Home** button resets all tools and restores the original graph view.

![Graph tools](images/placeholder_analysis_graph_tools.png)

## Saving Image

The **Save Image** button saves the current graph to an image file (PNG, FIG, etc.).

## Settings

The **Settings** button opens the artifact removal settings window (similar to Signal Viewer).

## Keyboard Shortcuts

- **Left/Right arrows** - time navigation/stimuli/events
- **Navigation keys** - depend on navigation mode

