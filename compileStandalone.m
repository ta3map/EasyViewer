function compileStandalone()
    projectRoot = fileparts(mfilename('fullpath'));
    outDir = fullfile(projectRoot, 'dist', 'EasyView');
    installerDir = fullfile(projectRoot, 'dist', 'installer');

    addpath(genpath(fullfile(projectRoot, 'functions')));
    addpath(fullfile(projectRoot, 'modules'));
    addpath(genpath(fullfile(projectRoot, 'Heka')));

    moduleFiles = dir(fullfile(projectRoot, 'modules', '*.m'));
    modulePaths = fullfile({moduleFiles.folder}, {moduleFiles.name});

    if exist(outDir, 'dir')
        rmdir(outDir, 's');
    end
    mkdir(outDir);

    mcc('-m', fullfile(projectRoot, 'app.m'), ...
        modulePaths{:}, ...
        '-o', 'EasyView', ...
        '-d', outDir);

    copyfile(fullfile(projectRoot, 'assets'), fullfile(outDir, 'assets'));
    copyfile(fullfile(projectRoot, 'configs'), fullfile(outDir, 'configs'));
    copyfile(fullfile(projectRoot, 'modules'), fullfile(outDir, 'modules'));
    copyfile(fullfile(projectRoot, 'docs'), fullfile(outDir, 'docs'));

    appText = fileread(fullfile(projectRoot, 'app.m'));
    versionTok = regexp(appText, "EV_version = '([^']+)'", 'tokens', 'once');
    version = versionTok{1};

    if exist(installerDir, 'dir')
        rmdir(installerDir, 's');
    end
    mkdir(installerDir);

    payloadZip = fullfile(installerDir, 'payload.zip');
    zip(payloadZip, {'EasyView.exe', 'assets', 'configs', 'modules', 'docs'}, outDir);

    installerExe = fullfile(installerDir, ['EasyView_' version '.exe']);
    csc = fullfile(getenv('WINDIR'), 'Microsoft.NET', 'Framework64', 'v4.0.30319', 'csc.exe');
    src = fullfile(projectRoot, 'installer', 'EasyViewUpdate.cs');

    cmd = sprintf('"%s" /nologo /target:winexe /utf8output /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /resource:"%s",payload.zip /out:"%s" "%s"', ...
        csc, payloadZip, installerExe, src);
    status = system(cmd);
    delete(payloadZip);
    if status ~= 0
        error('Failed to build installer');
    end
end
