function buildApplication()
    p = getDeployPaths();

    addpath(genpath(fullfile(p.projectRoot, 'functions')));
    addpath(genpath(fullfile(p.projectRoot, 'Heka')));

    if exist(p.applicationDir, 'dir')
        rmdir(p.applicationDir, 's');
    end
    mkdir(p.applicationDir);

    mcc('-o', 'EasyView', ...
        '-W', ['main:EasyView,version=' p.version], ...
        '-T', 'link:exe', ...
        '-d', p.applicationDir, ...
        '-R', '-logfile,easVieLog.txt', ...
        '-r', p.iconIco, ...
        fullfile(p.projectRoot, 'app.m'), ...
        '-a', fullfile(p.projectRoot, 'functions', 'sqlite-jdbc.jar'));

    copyfile(fullfile(p.projectRoot, 'assets'), fullfile(p.applicationDir, 'assets'));
    copyfile(fullfile(p.projectRoot, 'configs'), fullfile(p.applicationDir, 'configs'));
    copyfile(fullfile(p.projectRoot, 'docs'), fullfile(p.applicationDir, 'docs'));

    splashSrc = fullfile(p.resources, 'app_splash.png');
    if ~isfile(splashSrc)
        splashSrc = fullfile(p.resources, 'splash.png');
    end
    copyfile(splashSrc, fullfile(p.applicationDir, 'splash.png'));
end
