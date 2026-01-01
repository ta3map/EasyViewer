# Visualization

The program provides various tools for configuring signal and analysis results display.

## Channel Display Settings

### Channel Table

The Signal Viewer side panel contains a channel settings table:

- **Channel** - channel name
- **Enabled** - enable/disable channel display
- **Scale** - amplitude scaling coefficient
- **Color** - signal line color
- **Line Width** - line thickness
- **Averaging** - participation in averaging
- **CSD** - participation in CSD
- **Filter** - application of filtering
- **Baseline** - baseline subtraction

![Channel table](screenshots/channel_table.png)

### Quick Management

Buttons below the channel table:

- **(De)select ch** - toggle visibility of all channels
- **(De)select CSD** - toggle participation of all channels in CSD
- **(De)select Baseline** - toggle baseline subtraction

### Vertical Offset

The **Ch. Shift** field determines the vertical offset between channels in signal amplitude units. Increasing the value increases distance between channels on the graph.

## Colors and Line Styles

### Channel Color Configuration

Color of each channel is configured in the channel table. Standard MATLAB colors (r, g, b, k, m, c, y) or RGB values are available.

### Event and Stimulus Line Styles

Menu **View/Lines and styles** opens the line style settings window for events and stimuli.

**Parameters for each line type:**

- **Line Color** - line color
- **Line Style** - line style (-, --, :, -.)
- **Line Width** - line thickness
- **Label Text** - label text
- **Label Color** - label color
- **Label Font Size** - label font size
- **Label Background Color** - label background color
- **Label Font Weight** - font weight (normal/bold)

![Line style settings](screenshots/lines_styles.png)

## Zoom and Pan

### Built-in Zoom

Menu **View/Built-in Zoom** or **Zoom** button activates the built-in zoom tool.

**Usage:**

1. Activate Zoom
2. Select an area on the graph for zooming
3. Right-click to zoom out

![Zoom tool](screenshots/zoom.png)

### Built-in Pan

Menu **View/Built-in Pan** or **Pan** button activates the built-in panning tool.

**Usage:**

1. Activate Pan
2. Hold left mouse button and move the graph
3. Release button to finish

![Pan tool](screenshots/pan.png)

### Home

The **Home** button resets all tools (Zoom, Pan, Cursor) and restores the original graph view with automatic scaling.

## Data Cursor

Menu **View/Data Cursor** or **Cursor** button activates the data cursor.

**Usage:**

1. Activate Data Cursor
2. Click on the graph at the point of interest
3. Coordinates are displayed (time, amplitude, channel)

![Data Cursor](screenshots/data_cursor.png)

## Brush

The **Brush** button activates the data selection tool on the graph. Allows selecting data points for further analysis.

![Brush tool](screenshots/brush.png)

## Saving Graphs

### Saving Graph Snapshot

Menu **File/Save figure snapshot** in Signal Viewer saves the current graph to an image file.

**Formats:**

- PNG
- FIG (MATLAB figure)
- PDF
- EPS

![Saving graph](screenshots/save_figure.png)

### Saving Image in Signal Analysis

The **Save Image** button in Signal Analysis saves the current analysis graph.

## Axis Settings

### Time Units

The time units dropdown allows selection of:

- **s** - seconds
- **ms** - milliseconds
- **min** - minutes

The selected unit is applied to all time parameters and time axis display.

### Automatic Scaling

Graphs are automatically scaled for optimal data display. When using Zoom/Pan, scaling can be changed manually.

### Restoring Scale

The **Home** button restores automatic scaling and original graph view.

## Hiding Interface Elements

### Hiding Side Panel

The **×** button at the top of the side panel or menu **View/Hide Channel Settings** hides the side panel to increase the graph area.

The **□** button or menu **View/show Channel Settings** restores the panel.

### Hiding Stimuli

Menu **View/Hide stimulus** hides or shows stimulus display on the graph.

## CSD and MUA Display

### CSD

The **CSD** checkbox on the toolbar enables Current Source Density display. CSD settings are available through menu **View/CSD displaying**.

### MUA

The **MUA** checkbox enables multi-unit activity display. The **MUA coef** field sets the display threshold in standard deviation units.

## Graph Settings in Signal Analysis

In Signal Analysis, additional settings are available:

- Display of measurement elements (baseline, peak, slope, onset)
- Toggle between original and smoothed signal
- Mean trace display

All settings are applied immediately to the graph.

## Graph Export

Graphs can be exported to various formats:

- **PNG** - raster image
- **FIG** - MATLAB figure file
- **PDF** - vector format
- **EPS** - vector format for publications

Resolution for raster formats: 300 DPI.

