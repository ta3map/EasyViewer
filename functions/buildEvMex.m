function buildEvMex()
    src = fullfile(fileparts(mfilename('fullpath')), 'mex', 'evProcessSignal.cpp');
    outDir = fileparts(mfilename('fullpath'));
    mex('-O', '-largeArrayDims', src, '-outdir', outDir, '-output', 'evProcessSignal');
    fprintf('Built: %s\n', fullfile(outDir, ['evProcessSignal.' mexext]));
end
