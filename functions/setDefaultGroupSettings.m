function [newFs, shiftCoeff, time_back, time_forward, stim_offset] = setDefaultGroupSettings(numChannels, Fs)
    % SETDEFAULTGROUPSETTINGS Устанавливает значения по умолчанию для групповых настроек
    % 
    % Входные параметры:
    %   numChannels - количество каналов
    %   Fs - частота дискретизации исходных данных
    %
    % Выходные параметры:
    %   newFs - частота дискретизации для отображения
    %   shiftCoeff - коэффициент сдвига между каналами
    %   time_back - временное окно "до" (в секундах)
    %   time_forward - временное окно "после" (в секундах)
    %   stim_offset - время отступа для стимуляции (в секундах)
    
    % Значения по умолчанию для групповых настроек
    % Настройки фильтрации убраны - они устанавливаются только в индивидуальных настройках
    
    newFs = Fs;  % Используем исходную частоту дискретизации
    shiftCoeff = 200;
    time_back = 0.6;
    time_forward = 0.6;
    stim_offset = 0.0;  % По умолчанию без отступа
    
    disp('Default group settings applied (without filter settings, with stim offset)')
end 