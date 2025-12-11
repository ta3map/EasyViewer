---
name: Integrate SQL metadata into metadata analysis
overview: Pass selected file table rows to metadataAnalysis, which will extract SQL fields and include them in flatTable.
todos: []
---

# Integration of SQL Metadata into Metadata Analysis

## Overview

Pass selected rows from `fileTable` directly to `metadataAnalysis`. The function will extract SQL metadata fields and include them in the field selection dialog and resulting flatTable.

## Changes Required

### 1. Modify `metadataAnalysisCallback` in [`functions/fileManagerGUI.m`](functions/fileManagerGUI.m)

- Get selected rows from `fileTable` (from `state.selectedRows`)
- Extract selected rows data: `fileTable.Data(selectedRows, :)`
- Extract column names: `fileTable.ColumnName`
- Pass to `metadataAnalysis(metaPaths, fileIdArray, fileTableData, fileTableColumns)`

### 2. Update `metadataAnalysis` function signature in [`functions/metadataAnalysis.m`](functions/metadataAnalysis.m)

- Add optional parameters: `function metadataAnalysis(metaPaths, fileIds, fileTableData, fileTableColumns)`
- If `fileTableData` provided, extract SQL fields and add to selection dialog

### 3. Add SQL fields to selection dialog in [`functions/metadataAnalysis.m`](functions/metadataAnalysis.m)

- After extracting fields from first .meta file, if fileTableData provided:
- Extract metadata column names (skip first 3: 'File ID', 'File Name', 'Path')
- Add SQL field names with "sql." prefix (e.g., "sql.age", "sql.condition")
- Merge with .meta file field names
- Pass combined list to `showFieldSelectionDialog`

### 4. Modify `saveToMatDirect` function in [`functions/metadataAnalysis.m`](functions/metadataAnalysis.m)

- Add `fileTableData` and `fileTableColumns` parameters
- When processing each file:
- Check if selected field starts with "sql."
- If yes, find fileId in fileTableData and extract value from corresponding row
- If no, use existing `getFieldValue` for .meta file fields
- Add SQL field values to the flatTable

## Implementation Details

### Data Structure

- `fileTableData`: cell array from `fileTable.Data(selectedRows, :)` - selected rows from file table
- `fileTableColumns`: cell array from `fileTable.ColumnName` - column names
- First 3 columns are: 'File ID', 'File Name', 'Path'
- Remaining columns are metadata fields

### Field Naming

- SQL fields in dialog: `sql.{columnName}` for columns after first 3
- SQL field values: extracted from `fileTableData{rowIndex, columnIndex}` where rowIndex matches fileId

### Data Flow

1. User selects analysis results in `analysisTable`
2. `metadataAnalysisCallback` gets fileIds and metaPaths
3. Get selected rows from `fileTable` (from `state.selectedRows`)
4. Pass `fileTable.Data(selectedRows, :)` and `fileTable.ColumnName` to `metadataAnalysis`
5. `metadataAnalysis` extracts SQL field names and adds to selection dialog
6. User selects fields (including SQL fields)
7. `saveToMatDirect` collects both .meta and SQL field values from fileTableData
8. SQL field values added to flatTable