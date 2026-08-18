function appRoot = getAppRoot()
    if isdeployed
        exeFile = char(System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName);
        appRoot = fileparts(exeFile);
        return
    end
    appRoot = fileparts(mfilename('fullpath'));
end
