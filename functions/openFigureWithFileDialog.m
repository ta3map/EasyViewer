function openFigureWithFileDialog()
    [fileName, pathName] = uigetfile('*.fig', 'Select a MATLAB figure');
    if isequal(fileName, 0) || isequal(pathName, 0)
        disp('User canceled file selection.');
    else
        fullPath = fullfile(pathName, fileName);
        openfig(fullPath, 'reuse'); % Open figure
        set(gcf, 'Name', fileName, 'NumberTitle', 'off'); % Set the figure title to the file name
    end
end
