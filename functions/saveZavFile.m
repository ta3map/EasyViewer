function saveZavFile(filepath)
    % saveZavFile - сохраняет zav-файл с текущими глобальными переменными
    % filepath - полный путь к файлу для сохранения
    
    global spks lfp_file hd zavp chnlGrp lfpVar
    
    lfp = lfp_file.lfp;
    save(filepath, 'spks', 'lfp', 'hd', 'zavp', 'chnlGrp', 'lfpVar', '-v7.3');
    clear lfp;
end
