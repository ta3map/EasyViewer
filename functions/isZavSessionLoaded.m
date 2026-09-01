function tf = isZavSessionLoaded(matPath)
    global matFilePath hd lfp_file

    if nargin < 1 || isempty(matPath)
        matPath = matFilePath;
    end
    if isempty(matPath) || isempty(matFilePath) || isempty(hd)
        tf = false;
        return;
    end
    if isempty(lfp_file)
        tf = false;
        return;
    end
    tf = strcmpi(normalizeZavPath(matPath), normalizeZavPath(matFilePath));
end

function p = normalizeZavPath(p)
    if isempty(p)
        return;
    end
    p = char(java.io.File(p).getCanonicalPath());
end
