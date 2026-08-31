function path = canonicalIosPath(iosPath)
    path = char(java.io.File(iosPath).getCanonicalPath());
end
