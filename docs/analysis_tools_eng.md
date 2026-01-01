# Analysis Tools

The program provides various tools for analyzing electrophysiological signals.

## Z-score

Z-score normalization transforms the signal to a standard normal distribution.

**Opening:** Menu **Analysis/Z-score** in Signal Viewer

**Parameters:**

- Channel selection for normalization
- Calculation method (across entire signal or by window)

![Z-score normalization](screenshots/zscore.png)

## Spectral Density

Power spectral density shows the distribution of signal power across frequencies.

**Opening:** Menu **Analysis/Spectral Density** in Signal Viewer

**Parameters:**

- Channel selection for analysis
- Calculation method (FFT, Welch, etc.)
- Window size
- Window overlap

**Output data:**

- Spectral density graph
- Table with results

![Spectral density](screenshots/spectral_density.png)

## Cross-Correlation

Cross-correlation shows relationships between events or channels.

**Opening:** Menu **Analysis/Cross-Correlation** in Signal Viewer

### Event Cross-Correlation

Analysis of temporal relationships between events.

**Parameters:**

- Event selection for analysis
- Correlation time window
- Normalization method

![Event cross-correlation](screenshots/event_crosscorrelation.png)

### Channel Cross-Correlation

Analysis of relationships between channels.

**Parameters:**

- Channel selection for analysis
- Correlation time window
- Normalization method

![Channel cross-correlation](screenshots/channel_crosscorrelation.png)

## PCA (Principal Component Analysis)

Principal component analysis identifies main patterns in multi-channel data.

**Opening:** Menu **Analysis/PCA** in Signal Viewer

**Parameters:**

- Channel selection for analysis
- Number of principal components
- Data normalization method

**Output data:**

- Principal components graph
- Table with coefficients
- Explained variance graph

![PCA analysis](screenshots/pca.png)

## Data Operations

Channel data operations allow performing mathematical operations between channels.

**Opening:** Menu **Analysis/Data Operations** in Signal Viewer

**Available operations:**

- Channel addition
- Channel subtraction
- Channel multiplication
- Channel division
- Channel averaging

**Parameters:**

- Channel selection for operation
- Operation type
- Saving result as new channel

![Data operations](screenshots/data_operations.png)

## Compare Average Data

Comparing averaged data allows comparing mean traces between different conditions.

**Opening:** Menu **Analysis/Compare average data** in Signal Viewer

**Parameters:**

- Selection of two datasets for comparison
- Comparison time window
- Statistical comparison method

**Output data:**

- Graph with overlaid mean traces
- Statistical difference indicators

![Compare average data](screenshots/compare_average.png)

## Boxplot from Table

Building boxplots from measurement results table.

**Opening:** Menu **Analysis/Boxplot from Table** in Signal Viewer

**Parameters:**

- Excel file selection with data
- Column selection for boxplot construction
- Data grouping
- Visualization settings

**Output data:**

- Graph with boxplots
- Statistical indicators

Detailed description: [Boxplot from Table](boxplotFromTableGUI_eng.md)

![Boxplots from table](screenshots/boxplot_table.png)

## Using Analysis Tools

### Data Selection

Most tools require preliminary data loading in Signal Viewer or Signal Analysis.

### Parameter Configuration

Each tool has its own settings window with parameters specific to the analysis method.

### Saving Results

Analysis results can be saved:

- As graphs (PNG, FIG)
- As tables (Excel)
- As data (MAT)

### File Manager Integration

Analysis results can be saved to the File Manager database for subsequent viewing and comparison.

