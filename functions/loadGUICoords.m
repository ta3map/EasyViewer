function [coordsData, coordsFile] = loadGUICoords(configFileName)
    coordsFile = getGUIConfigPath(configFileName);
    if exist(coordsFile, 'file')
        coordsData = jsondecode(fileread(coordsFile));
    else
        error('Coordinates file not found: %s', coordsFile);
    end
end
