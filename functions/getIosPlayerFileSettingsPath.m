function settingsPath = getIosPlayerFileSettingsPath(iosPath)
    canonicalPath = canonicalIosPath(iosPath);
    md = java.security.MessageDigest.getInstance('MD5');
    hashBytes = typecast(md.digest(uint8(canonicalPath)), 'uint8');
    hashStr = lower(reshape(dec2hex(hashBytes, 2)', 1, []));
    settingsDir = fullfile(tempdir, 'ev_iosplayer');
    settingsPath = fullfile(settingsDir, [hashStr '.stn']);
end
