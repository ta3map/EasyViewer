function data = readAndCheckOEPdata(directory, primaryFile, fallbackFile)
    % Construct full paths for the primary and fallback files
    primaryFilePath = fullfile(directory, primaryFile);
    fallbackFilePath = fullfile(directory, fallbackFile);
    
    % Try reading the primary file if it exists
    if isfile(primaryFilePath)
        data = readNPY(primaryFilePath);
    % If the primary file doesn't exist, try reading the fallback file
    elseif isfile(fallbackFilePath)
        data = readNPY(fallbackFilePath);
    % If neither file exists, return an empty array
    else
        data = [];
    end
end
