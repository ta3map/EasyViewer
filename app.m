function app()
    % Глобальная переменная версии приложения
    global EV_version
    EV_version = '1.12.05';
    
    % Проверяем, не открыто ли уже окно
    existingFig = findobj('Tag', 'EasyViewerApp');
    if ~isempty(existingFig)
        figure(existingFig);
        return;
    end
    
    % Создаем главное окно
    f = figure('Name', ['EasyViewer App v' EV_version], ...
              'NumberTitle', 'off', ...
              'MenuBar', 'none', ...
              'ToolBar', 'none', ...
              'Position', [100, 100, 400, 300], ...
              'Resize', 'off', ...
              'Tag', 'EasyViewerApp', ...
              'CloseRequestFcn', @closeApp);
    
    % Закрываем все другие окна перед открытием главного окна
    closeAllButOne(f);
    
    % Создаем панель для кнопок
    panel = uipanel('Parent', f, ...
                   'Position', [0.1, 0.1, 0.8, 0.8]);
    
    % Кнопка для запуска signalViewerGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Signal Viewer', ...
             'Position', [40, 120, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @(~,~)signalViewerGUI());
    
    % Кнопка для запуска signalAnalysisGUI
    uicontrol('Parent', panel, ...
             'Style', 'pushbutton', ...
             'String', 'Signal Analysis', ...
             'Position', [40, 40, 240, 60], ...
             'FontSize', 14, ...
             'Callback', @(~,~)signalAnalysisGUI());
    
    % Закрываем все фигуры, кроме указанной
    function closeAllButOne(targetFigure)
        % Получаем массив всех текущих фигур
        figures = findobj(allchild(0), 'flat', 'Type', 'figure');
        % Перебираем все фигуры и закрываем те, которые не совпадают с целевой
        for i = 1:length(figures)
            if figures(i) ~= targetFigure
                close(figures(i));
            end
        end
    end
    
    % Функция обработки закрытия главного окна
    function closeApp(src, ~)
        % Закрываем все дочерние окна
        closeAllButOne(src);
        
        % Закрываем главное окно
        delete(src);
    end
end 