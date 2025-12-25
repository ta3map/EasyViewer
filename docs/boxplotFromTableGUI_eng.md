# boxplotFromTableGUI - Documentation

## Overview

`boxplotFromTableGUI` is a MATLAB GUI application for creating boxplots from flat tables (MAT files with `flatTable` variable or Excel files). It supports data filtering using MATLAB formulas, statistical analysis, and customizable visualization options.

## Function Signature

```matlab
boxplotFromTableGUI(filePath)
```

### Input Parameters

- `filePath` (optional): Path to MAT file (with `flatTable` variable) or Excel file to load automatically. If not provided, user can load file manually via GUI.

## Features

### 1. Data Loading

- **MAT Files**: Loads `flatTable` variable from `.mat` files
- **Excel Files**: Supports `.xlsx` and `.xls` formats using `readtable`
- **Column Preview**: Displays available columns in a listbox
- **Data Preview**: Shows selected column data in a preview table

### 2. Group Filtering

Filter format: `A: condition1; B: condition2`

- Groups are separated by `;` or newlines
- Group labels: A, B, C, etc.
- Conditions are pure MATLAB formulas (e.g., `age > 5`, `age <= 5 & age < 10`)
- Conditions are evaluated using `eval` with table column variables available
- Filter diagnostics available via "Check Filters" button

### 3. Analysis Parameters

- Select columns for analysis (one per line)
- Each column will be plotted as a separate subplot
- Columns are validated against table structure

### 4. Custom Group Labels

Format: `A:Label1,B:Label2` or one per line

- Maps group letters to custom display labels
- If not specified, group letters (A, B, C) are used

### 5. Custom Group Colors

Format: `A:#FF0000,B:#00FF00` or one per line

- HEX color codes converted to RGB
- Applied to scatter points for each group
- Default: black if not specified

### 6. Statistical Analysis

- **Descriptive Statistics**: Mean, std, median, q25, q75, count for each group and parameter
- **Statistical Tests**: Optional pairwise t-tests (`ttest2`) between all groups
- **Significance Brackets**: Multi-level positioning to avoid overlaps
- **P-value Display**: Shows p-values with stars (`***` p<0.001, `**` p<0.01, `*` p<0.05, `ns` otherwise)
- **Show All P-values**: Option to show all p-values or only significant ones (p < 0.05)

### 7. Visualization

- **Layout**: All plots in a single column (one below another)
- **Boxplots**: Standard MATLAB `boxplot` with grouping
- **Data Points**: Individual data points displayed with jitter using `scatter`
- **Annotations**: `n=X` annotation on median for each group
- **Y-axis Range**: 
  - Auto: Automatic scaling
  - Manual: User-defined min/max values
- **Title**: Customizable plot title

### 8. Export

- **Formats**: PNG, PDF, FIG, EPS
- **Resolution**: 300 DPI for raster formats
- Exports the current plot figure

## Usage

### Basic Usage

```matlab
% Open GUI without pre-loading file
boxplotFromTableGUI();

% Open GUI and load file automatically
boxplotFromTableGUI('path/to/data.mat');
boxplotFromTableGUI('path/to/data.xlsx');
```

### Workflow

1. **Load Data**: Click "Load File" or provide `filePath` parameter
2. **Preview Columns**: Select column in listbox to see data preview
3. **Set Filters**: Enter group filters in format `A: condition1; B: condition2`
4. **Check Filters** (optional): Verify filter results
5. **Select Analysis Columns**: Enter column names (one per line)
6. **Configure Options**:
   - Custom group labels (optional)
   - Custom group colors (optional)
   - Show statistics checkbox
   - Show all p-values checkbox
   - Y-axis range (auto/manual)
   - Plot title
7. **Plot**: Click "Plot" button
8. **Export** (optional): Click "Export Plot" to save figure

### Filter Examples

```
A: age > 5
B: age <= 5
```

```
A: age > 5 & age < 10
B: age >= 10
C: condition == 'control'
```

### Group Labels Example

```
A:Young
B:Old
```

### Group Colors Example

```
A:#FF0000
B:#00FF00
C:#0000FF
```

## Technical Details

### Data Structure

The function expects:
- **MAT files**: Variable named `flatTable` (MATLAB `table` object)
- **Excel files**: Standard table format with header row

### Filter Evaluation

- Table column names are made valid MATLAB variable names using `matlab.lang.makeValidName`
- Variables are assigned to base workspace for `eval` context
- Conditions are evaluated row-by-row to create logical masks
- Rows matching any group condition are included in analysis

### Statistical Tests

- Uses MATLAB's `ttest2` for pairwise comparisons
- Tests all unique pairs of groups for each parameter
- Results stored in structure: `pvalue`, `n1`, `n2`, `group1`, `group2`

### Significance Brackets

- Multi-level positioning algorithm prevents overlaps
- Brackets positioned above data with configurable spacing
- Y-axis limits automatically adjusted to accommodate brackets

## GUI Layout

- **Left Panel** (400px width): Controls and settings
- **Right Panel**: Plot display area
- **Elements** (top to bottom):
  - Data loading section
  - Available columns listbox
  - Column data preview table
  - Group filters textarea
  - Analysis columns textarea
  - Group labels input
  - Group colors input
  - Visualization options
  - Y-axis controls
  - Title input
  - Action buttons (Plot, Export)

## Error Handling

- Validates file existence and format
- Checks for required `flatTable` variable in MAT files
- Validates column names against table structure
- Shows error messages via `msgbox` for user feedback
- Filter errors are caught and displayed in diagnostics

## Dependencies

- MATLAB Statistics and Machine Learning Toolbox (for `boxplot`, `ttest2`)
- Standard MATLAB functions: `readtable`, `uitable`, `uicontrol`, `figure`

## Notes

- GUI state is preserved in figure's `UserData`
- Window coordinates can be saved/loaded from JSON file
- If GUI is already open, calling function again brings it to front
- If `filePath` provided and GUI open, file is loaded into existing window

