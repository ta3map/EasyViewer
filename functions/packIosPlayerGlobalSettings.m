function settings = packIosPlayerGlobalSettings(state)
    settings = struct();
    settings.contrast = state.h.contrastSlider.Value;
    settings.gaussianSigma = state.gaussianSigma;
    settings.speedPopupValue = state.h.speedPopup.Value;
    settings.colormapScheme = state.colormapScheme;
    settings.noiseFilterType = state.noiseFilterType;
    settings.noiseFilterParam = state.noiseFilterParam;
    settings.referenceSize = state.referenceSize;
    settings.showIosValues = state.showIosValues;
    settings.showChart = state.h.showChartCheck.Value;
    settings.chartSmoothWindow = state.chartSmoothWindow;
    if ~isempty(state.iosPath) && ischar(state.iosPath)
        settings.lastOpenedPath = state.iosPath;
    end
end
