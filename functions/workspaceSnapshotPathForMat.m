function snapshotPath = workspaceSnapshotPathForMat(matPath)
%WORKSPACESNAPSHOTPATHFORMAT Snapshot path in system temp keyed by MAT file path.

    canonicalPath = canonicalMatPath(matPath);
    md = java.security.MessageDigest.getInstance('MD5');
    hashBytes = typecast(md.digest(uint8(canonicalPath)), 'uint8');
    hashStr = lower(reshape(dec2hex(hashBytes, 2)', 1, []));
    snapshotPath = fullfile(tempdir, ['ev_workspace_' hashStr '.mat']);
end

function canonical = canonicalMatPath(matPath)
    canonical = char(matPath);
    if isempty(canonical)
        return;
    end
    try
        canonical = char(java.io.File(canonical).getCanonicalPath());
    catch
        canonical = canonicalMatPathFallback(canonical);
    end
end

function canonical = canonicalMatPathFallback(matPath)
    [pathPart, namePart, extPart] = fileparts(matPath);
    if isempty(pathPart)
        pathPart = pwd;
    end
    canonical = fullfile(pathPart, [namePart extPart]);
end
