% Function to return accumulated non-empty data from multiple specified columns of the table
function accumulatedData = getOpenEphysAccumulatedData(dataTable, columnNames)

    % Check if the specified columns exist in the table
    for col = 1:length(columnNames)
        if ~ismember(columnNames{col}, dataTable.Properties.VariableNames)
            error('The specified column "%s" does not exist in the table.', columnNames{col});
        end
    end

    % Initialize a structure to hold accumulated data for each column
    accumulatedData = struct();

    % Iterate through each column name
    for col = 1:length(columnNames)
        columnName = columnNames{col};

        % Initialize an empty cell array to hold the accumulated data for this column
        accumulatedData.(columnName) = {};

        % Get the column data
        columnData = dataTable.(columnName);

        % Iterate through each row and accumulate non-empty data
        for i = 1:height(dataTable)
            currentData = columnData{i};

            % Check if the current entry is not empty
            if ~isempty(currentData)
                % Append the current data (as a full array, not its content) to the accumulated list
                accumulatedData.(columnName){end+1, 1} = currentData;  % Add currentData as a whole array
            end
        end
    end
end
