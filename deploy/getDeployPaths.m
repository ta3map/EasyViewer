function p = getDeployPaths()
    p.deployRoot = fileparts(mfilename('fullpath'));
    p.projectRoot = fileparts(p.deployRoot);
    p.resources = fullfile(p.deployRoot, 'resources');
    p.applicationDir = fullfile(p.deployRoot, 'out', 'application');
    p.updateDir = fullfile(p.deployRoot, 'out', 'update');
    p.updatePublishDirs = {
        '\\10.167.11.29\data1\Gainutdinov'
        'C:\Users\AzaRGajnutdinov\Dropbox\Easy Viewer'
    };
    p.fullDir = fullfile(p.deployRoot, 'out', 'full');
    p.updateStub = fullfile(p.deployRoot, 'updateStub', 'UpdateInstaller.cs');
    p.iconIco = fullfile(p.resources, 'icon.ico');
    appText = fileread(fullfile(p.projectRoot, 'app.m'));
    versionTok = regexp(appText, "EV_version = '([^']+)'", 'tokens', 'once');
    p.version = versionTok{1};
end
