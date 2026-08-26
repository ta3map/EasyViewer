function buildUpdateInstaller()
    p = getDeployPaths();
    appExe = fullfile(p.applicationDir, 'EasyView.exe');
    if ~isfile(appExe)
        error('Run deploy/buildApplication first: %s not found', appExe);
    end

    if exist(p.updateDir, 'dir')
        rmdir(p.updateDir, 's');
    end
    mkdir(p.updateDir);

    payloadZip = fullfile(p.updateDir, 'payload.zip');
    zip(payloadZip, {'EasyView.exe', 'splash.png', 'assets', 'configs', 'docs'}, p.applicationDir);

    installerExe = fullfile(p.updateDir, ['EasyView_' p.version '.exe']);
    csc = fullfile(getenv('WINDIR'), 'Microsoft.NET', 'Framework64', 'v4.0.30319', 'csc.exe');

    cmd = sprintf('"%s" /nologo /target:winexe /utf8output /win32icon:"%s" /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /resource:"%s",payload.zip /out:"%s" "%s"', ...
        csc, p.iconIco, payloadZip, installerExe, p.updateStub);
    status = system(cmd);
    delete(payloadZip);
    if status ~= 0
        error('Failed to build update installer');
    end
end
