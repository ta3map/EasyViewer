---
name: ""
overview: ""
todos: []
---

# Integration of SQL Metadata into Metadata Analysis

## Overview

Modify the metadata analysis process to include SQL metadata from the existing file table in fileManagerGUI. The table already displays all file metadata from `state.metadataData` and `state.metadataFields`. Simply extract this data for selected files and pass it to `metadataAnalysis` alongside .meta file fields. **No SQL queries needed** - data is already loaded and displayed in the file table.

## Changes Required

### 1. Modify `metadataAnalysisCallback` in [`functions/fileManagerGUI.m`](functions/fileManagerGUI.m)

   - The file table already shows all metadata from `state.metadataData` and `state.metadataFields`
   - Extract SQL metadata for selected files from `state.metadataData` (already in memory)
   - Filter `state.metadataData` to only include entries for selected fileIds (keys like `f1`, `f2`, etc.)
   - Pass SQL metadata to `metadataAnalysis` as a third parameter
   - Structure: `sqlMetadata = struct('fileIds', fileIdArray, 'fields', state.metadataFields, 'data', filteredMetadataData, 'fieldNameMap', state.fieldNameMap)`
   - Note: `state.metadataData` uses keys like `f{fileId}` (e.g., `f1`, `f2`) with nested structures containing safe field names as keys

### 2. Update `metadataAnalysis` function signature in [`functions/metadataAnalysis.m`](functions/metadataAnalysis.m)

   - Add optional third parameter: `function metadataAnalysis(metaPaths, fileIds, sqlMetadata)`
   - If `sqlMetadata` is provided and not empty, extract SQL fields and merge with .meta file fields

### 3. Merge SQL fields with .meta file fields

   - In `metadataAnalysis`, after extracting fields from first .meta file:
     - If SQL metadata provided, extract field names from `sqlMetadata.fields` (original field names from the table)
     - Prefix SQL fields with "sql." to distinguish them (e.g., "sql.age", "sql.condition")
     - Merge SQL field names with .meta file field names
     - Pass combined list to `showFieldSelectionDialog`

### 4. Modify `saveToMatDirect` function in [`functions/metadataAnalysis.m`](functions/metadataAnalysis.m)

   - Add `sqlMetadata` parameter: `function success = saveToMatDirect(metaPaths, fileIds, selectedFields, savePath, sqlMetadata)`
   - When processing each file in the loop:
     - Check if selected field starts with "sql."
     - If yes, extract value from SQL metadata structure using `getSqlFieldValue`
     - If no, use existing `getFieldValue` for .meta file fields

### 5. Create `getSqlFieldValue` helper function in [`functions/metadataAnalysis.m`](functions/metadataAnalysis.m)

   - Function: `function value = getSqlFieldValue(sqlMetadata, fileId, fieldName)`
   - Extract field name after "sql." prefix (e.g., "sql.age" -> "age")
   - Convert original field name to safe field name using `makeSafeFieldName` (or use `sqlMetadata.fieldNameMap` if provided)
   - Look up value in `sqlMetadata.data` using fileId key (format: `f{fileId}`) and safe field name
   - Return field value (string) or empty if not found
   - Note: SQL metadata values are always strings from the database

### 6. Update field extraction logic

   - In `saveToMatDirect`, when analyzing field structure:
     - Skip SQL fields during structure analysis (they are always strings)
     - Only analyze .meta file fields for structure information

## Implementation Details

### SQL Metadata Structure

```matlab
sqlMetadata = struct(
    'fileIds', [1, 2, 3],           % Array of file IDs (matches fileIdArray from callback)
    'fields', {'age', 'condition'}, % Cell array of original field names from state.metadataFields (as shown in table)
    'data', struct(                 % Nested structure from state.metadataData: f{fileId}.{safeFieldName}
        'f1', struct('age', '25', 'condition', 'A'),  % safeFieldName matches original if valid
        'f2', struct('age', '30', 'condition', 'B')
    ),
    'fieldNameMap', struct(         % Mapping from safe names to original names (from state.fieldNameMap)
        'age', 'age',
        'condition', 'condition'
    )
)
```

Note: The structure matches exactly what's stored in `state.metadataData` in fileManagerGUI, which is already displayed in the file table. Keys are `f{fileId}` and values are structures with safe field names as keys. Original field names are in `state.metadataFields` (as shown in table columns).

### Field Naming Convention

- .meta file fields: `meanData.timeAxis`, `calculation_result.Fs`, etc.
- SQL metadata fields: `sql.age`, `sql.condition`, etc. (using original field names from `state.metadataFields` as shown in the table)

### Data Flow

1. User selects analysis results in File Manager
2. `metadataAnalysisCallback` extracts SQL metadata from `state.metadataData` (already loaded and shown in file table)

   - Filter `state.metadataData` to only include entries for selected fileIds
   - Use `state.metadataFields` for original field names (same as table column names)
   - Include `state.fieldNameMap` for safe-to-original name mapping

3. SQL metadata passed to `metadataAnalysis` along with .meta paths and fileIds
4. Fields merged and shown in selection dialog
5. Selected fields (including SQL) processed and saved to flatTable
6. When processing each file, use fileId to match SQL metadata from `sqlMetadata.data.f{fileId}`

## Key Points

- **No SQL queries**: All data comes from `state.metadataData` which is already loaded and displayed in the file table
- **Table data**: The file table already shows all metadata - we just need to extract it for selected files
- **fileId matching**: Use fileId to match SQL metadata entries (keys: `f{fileId}`) with corresponding .meta files
- **Safe field names**: SQL metadata uses safe field names as keys in nested structures, but original names are in `sqlMetadata.fields` (same as table column names)
- **String values**: SQL metadata values are always strings from the database

## Testing Considerations

- Test with files that have both SQL and .meta metadata
- Test with files that have only SQL metadata (no .meta file)
- Test with files that have only .meta metadata (no SQL metadata)
- Verify SQL fields appear correctly in resulting flatTable
- Verify fileId matching works correctly when fileIds don't match array indices
- Verify that SQL metadata fields match what's shown in the file table