# Data Flow Diagram - boxplotFromTableGUI (Updated v3)

```mermaid
flowchart TD
    Start([User Action]) --> LoadFile[loadFileCallback]
    Start --> AddParam[addColumnToAnalysis]
    Start --> EditFilter[paramsTableEditCallback]
    Start --> Plot[plotBoxplotCallback]
    
    LoadFile --> LoadFileInGUI[loadFileInGUI]
    LoadFileInGUI --> FormatTable[boxplotFormatTableColumnNames]
    FormatTable --> State1["state.table = formatted table"]
    State1 --> State2["state.parameters = empty"]
    State2 --> State3["state.filteredData = struct"]
    State3 --> UpdateUI1["Update UI: columnsList, filePathText"]
    State3 --> UpdateDisplay1[updateAnalysisColumnsDisplay]
    
    AddParam --> CheckTable{"state.table empty?"}
    CheckTable -->|Yes| Return1[return]
    CheckTable -->|No| AddToParams["Add to state.parameters<br/>with all fields"]
    AddToParams --> UpdateDisplay2[updateAnalysisColumnsDisplay]
    UpdateDisplay2 --> UpdateFiltered1[updateFilteredDataStructure]
    
    EditFilter --> CheckParams{"paramsTable or<br/>parameters empty?"}
    CheckParams -->|Yes| Return2[return]
    CheckParams -->|No| UpdateParams["Update state.parameters<br/>from table data"]
    UpdateParams --> UpdateFiltered2[updateFilteredDataStructure]
    
    UpdateFiltered1 --> ParseFilters["For each parameter:<br/>boxplotParseGroupFilters"]
    UpdateFiltered2 --> ParseFilters
    ParseFilters --> ApplyFilters[boxplotApplyGroupFilters]
    ApplyFilters --> FilterData["Filter data:<br/>Remove NaN/Inf"]
    FilterData --> CalcStats["Calculate statistics:<br/>mean, std, median, q25, q75, count"]
    CalcStats --> ParseColor["Parse color string<br/>to RGB array"]
    ParseColor --> CreateStruct["Create struct with:<br/>data, column, label, color,<br/>parsedColor, lineWidth,<br/>groupNumber, filter,<br/>fieldName, stats"]
    CreateStruct --> State4["state.filteredData.fieldName = struct"]
    State4 --> Console["Print to console:<br/>fieldName: filter, size, median, std"]
    
    Plot --> CheckTable2{"state.table empty?"}
    CheckTable2 -->|Yes| Return3[return]
    CheckTable2 -->|No| GetUI["Get UI controls:<br/>showStatsCheck, yAxisPopup, etc."]
    GetUI --> UpdateState["Update state:<br/>showStatistics, yAxisRange, title"]
    UpdateState --> CreateBoxplot[createBoxplotFigure]
    
    CreateBoxplot --> CheckFiltered{"state.filteredData<br/>empty?"}
    CheckFiltered -->|Yes| Return4[return]
    CheckFiltered -->|No| InitTests["statisticalTests = struct"]
    InitTests --> GetFields["Get fieldnames from<br/>state.filteredData"]
    GetFields --> GroupByNumber["Group by groupNumber"]
    GroupByNumber --> ForEachGroup["For each group number"]
    ForEachGroup --> ExtractData["Extract from filteredData:<br/>data, label, parsedColor,<br/>lineWidth, fieldName"]
    ExtractData --> BuildMap["Build displayLabelToParamData Map<br/>and paramDataMap"]
    BuildMap --> BuildBoxplot["boxplot: allDataForGroup,<br/>groupLabelsForBoxplot"]
    BuildBoxplot --> ApplyColors["Apply colors to patches & lines<br/>using parsedColor"]
    ApplyColors --> AddScatter["Add scatter points with jitter"]
    AddScatter --> UseStatsMedian["Use stats.median for text position"]
    UseStatsMedian --> CalcTests["Calculate t-test between params<br/>if showStatistics"]
    CalcTests --> AddBrackets[Add significance brackets]
    
    style State1 fill:#e1f5ff
    style State2 fill:#e1f5ff
    style State3 fill:#e1f5ff
    style State4 fill:#e1f5ff
    style ParseColor fill:#ffffcc
    style BuildMap fill:#ffffcc
    style UseStatsMedian fill:#90ee90
```

## Избыточные проверки полей (можно убрать):

### 1. **isfield(paramData, 'data')** (строка 879)
   - **Избыточно** - поле `data` всегда создается в `updateFilteredDataStructure`
   - **Можно заменить** на проверку `isempty(paramData.data)`

### 2. **isfield(paramData, 'label')** (строка 888)
   - **Избыточно** - поле `label` всегда создается в структуре параметра
   - **Можно убрать** проверку, оставить только `~isempty(paramData.label)`

### 3. **isfield(paramData, 'fieldName')** (строки 896, 936)
   - **Избыточно** - `fieldName` всегда добавляется в `updateFilteredDataStructure` (строка 776)
   - **Можно убрать** - использовать напрямую `paramData.fieldName`

### 4. **isfield(paramData, 'parsedColor')** (строка 916)
   - **Избыточно** - `parsedColor` всегда создается в `updateFilteredDataStructure` (строка 767)
   - **Можно убрать** - использовать напрямую `paramData.parsedColor`

### 5. **isfield(paramData, 'lineWidth')** (строки 921, 992, 1039)
   - **Избыточно** - `lineWidth` всегда создается в структуре параметра
   - **Можно убрать** проверку, оставить только `~isempty(paramData.lineWidth)` если нужно

### 6. **isfield(paramDataForLabel, 'lineWidth')** (строки 992, 1039)
   - **Избыточно** - `lineWidth` всегда есть в структуре
   - **Можно убрать** - использовать напрямую

### 7. **isfield(paramsInGroup{1}, 'column')** (строка 1109)
   - **Избыточно** - `column` всегда есть в структуре
   - **Можно убрать** проверку

### 8. **isfield(paramDataForLabel, 'stats') && isfield(paramDataForLabel.stats, 'median')** (строка 1058)
   - **Избыточно** - `stats` всегда создается в `updateFilteredDataStructure` (строка 777)
   - **Можно упростить** до `paramDataForLabel.stats.median` с проверкой на NaN

### 9. **isfield(paramData, 'groupNumber')** (строки 830, 848, 852)
   - **Частично избыточно** - `groupNumber` всегда создается в структуре параметра
   - **Можно упростить** - использовать напрямую с fallback на 1

## Рекомендации:

1. **Убрать проверки isfield** для полей, которые всегда создаются:
   - `data`, `label`, `fieldName`, `parsedColor`, `lineWidth`, `column`, `stats`
   
2. **Оставить проверки** только для:
   - `isempty()` - проверка на пустые значения
   - `isKey()` - проверка наличия ключа в Map
   - Условные поля, которые могут отсутствовать

3. **Использовать значения по умолчанию** вместо проверок:
   - `color = paramData.parsedColor;` вместо `if isfield(...)`
   - `paramLineWidth = paramData.lineWidth;` вместо проверки
