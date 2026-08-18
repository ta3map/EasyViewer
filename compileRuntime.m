function compileRuntime()
    projectRoot = fileparts(mfilename('fullpath'));
    outDir = fullfile(projectRoot, 'dist', 'runtime');

    installerPath = mcrinstaller;

    if exist(outDir, 'dir')
        rmdir(outDir, 's');
    end
    mkdir(outDir);

    unzip(installerPath, outDir);
end
