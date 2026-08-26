function coef = loadCsdContrastCoefFromSettings(loadedSettings)
%LOADCSDCONTRASTCOEFFROMSETTINGS Display contrast % from .stn; legacy percentile ignored.

coef = 100;
if ~isstruct(loadedSettings)
    return
end
if ~isfield(loadedSettings, 'csd_contrast_is_display') || ~logical(loadedSettings.csd_contrast_is_display)
    return
end
if ~isfield(loadedSettings, 'csd_contrast_coef')
    return
end
coef = normalizeCsdContrastCoef(loadedSettings.csd_contrast_coef);
end
