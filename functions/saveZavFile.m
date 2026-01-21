function saveZavFile(filepath)
    % saveZavFile - сохраняет zav-файл с текущими глобальными переменными
    % filepath - полный путь к файлу для сохранения
    
    global spks lfp hd zavp chnlGrp lfpVar
    
    % Сохранение всех необходимых переменных
    save(filepath, 'spks', 'lfp', 'hd', 'zavp', 'chnlGrp', 'lfpVar');
end
