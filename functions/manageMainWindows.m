function manageMainWindows(closingWindowTag)
%MANAGEMAINWINDOWS Управляет главными окнами приложения
%   При закрытии главного окна проверяет наличие других главных окон
%   и открывает app.m, если все главные окна закрыты
%
%   Входные параметры:
%   closingWindowTag - тег закрывающегося окна ('EasyViewerApp', 
%                      'SignalViewerGUI', 'SignalAnalysisGUI', 'plotFromTableGUI')

    % Определяем теги главных окон
    mainWindowTags = {'EasyViewerApp', 'SignalViewerGUI', 'SignalAnalysisGUI', 'plotFromTableGUI'};
    
    % Проверяем наличие других главных окон
    otherMainWindowsExist = false;
    for i = 1:length(mainWindowTags)
        tag = mainWindowTags{i};
        if ~strcmp(tag, closingWindowTag)
            existingFig = findobj('Type', 'figure', 'Tag', tag);
            if ~isempty(existingFig)
                otherMainWindowsExist = true;
                break;
            end
        end
    end
    
    % Если других главных окон нет, открываем app.m
    if ~otherMainWindowsExist
        app();
    end
end
