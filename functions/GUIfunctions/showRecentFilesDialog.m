function showRecentFilesDialog(lastOpenedFiles, openFileCallback)
selectedRow = [];

tableData_rf = cell(0, 2);
reversedAll = lastOpenedFiles(end:-1:1);
[~, uniqueIdx] = unique(lower(reversedAll), 'stable');
reversed = reversedAll(uniqueIdx);
for i = 1:numel(reversed)
    [~, fname, fext] = fileparts(reversed{i});
    tableData_rf{i, 1} = [fname, fext];
    tableData_rf{i, 2} = reversed{i};
end

dlgWidth = 600;
dlgHeight = 400;
screenSize = get(0, 'ScreenSize');
dlgPos = [(screenSize(3) - dlgWidth) / 2, (screenSize(4) - dlgHeight) / 2, dlgWidth, dlgHeight];

dlg = figure('Name', 'Recent files', 'NumberTitle', 'off', ...
    'MenuBar', 'none', 'ToolBar', 'none', ...
    'WindowStyle', 'modal', 'Resize', 'off', ...
    'Position', dlgPos);

recentTable = uitable('Parent', dlg, ...
    'Data', tableData_rf, ...
    'ColumnName', {'File name', 'Path'}, ...
    'RowName', {}, ...
    'ColumnEditable', [false false], ...
    'ColumnWidth', {180, 380}, ...
    'Position', [10, 50, 580, 340], ...
    'CellSelectionCallback', @onCellSelection);

btnOpen = uicontrol('Parent', dlg, 'Style', 'pushbutton', ...
    'String', 'Open File', 'Position', [10, 10, 140, 30], ...
    'Enable', 'off', 'Callback', @onOpen);

    function onCellSelection(~, evt)
        if ~isempty(evt.Indices)
            selectedRow = evt.Indices(1, 1);
            set(btnOpen, 'Enable', 'on');
        end
    end

    function onOpen(~, ~)
        filePath_rf = recentTable.Data{selectedRow, 2};
        close(dlg);
        openFileCallback(filePath_rf);
    end
end
