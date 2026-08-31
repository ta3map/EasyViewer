function state = applyIosPlayerGlobalSettings(fig, settings)
    state = fig.UserData;
    if isempty(settings) || ~isstruct(settings)
        fig.UserData = state;
        return
    end
    nSpeed = numel(state.h.speedPopup.String);
    nColormap = numel(state.h.colormapPopup.String);
    nNoise = numel(state.h.noiseFilterPopup.String);
    if isfield(settings, 'contrast')
        state = applyIosPlayerPipelineParam(state, 'contrast', settings.contrast);
    end
    if isfield(settings, 'gaussianSigma')
        state = applyIosPlayerPipelineParam(state, 'gaussianSigma', settings.gaussianSigma);
    end
    if isfield(settings, 'speedPopupValue') && nSpeed >= 1
        v = max(1, min(nSpeed, round(settings.speedPopupValue)));
        state.h.speedPopup.Value = v;
    end
    if isfield(settings, 'colormapScheme') && ischar(settings.colormapScheme)
        state.colormapScheme = settings.colormapScheme;
        list = state.h.colormapPopup.String;
        idx = find(strcmpi(list, settings.colormapScheme), 1);
        if ~isempty(idx)
            state.h.colormapPopup.Value = idx;
        end
        colormap(fig, state.colormapScheme);
    end
    if isfield(settings, 'noiseFilterType')
        state.noiseFilterType = settings.noiseFilterType;
        list = {'none','median','wiener','highpass'};
        idx = find(strcmpi(list, settings.noiseFilterType), 1);
        if ~isempty(idx) && idx <= nNoise
            state.h.noiseFilterPopup.Value = idx;
        end
        state = applyIosPlayerNoiseFilterUi(state, state.noiseFilterType);
    end
    if isfield(settings, 'noiseFilterParam')
        p = double(settings.noiseFilterParam);
        state.noiseFilterParam = p;
        state.h.blurSigmaSlider.Value = p;
        state.h.blurSigmaEdit.String = formatIosPlayerNoiseFilterParam(state);
    end
    if isfield(settings, 'referenceSize')
        state.referenceSize = settings.referenceSize;
        state.h.referenceSizeEdit.String = num2str(state.referenceSize);
    end
    if isfield(settings, 'showIosValues')
        state.showIosValues = logical(settings.showIosValues);
        state.h.showIosCheck.Value = double(state.showIosValues);
    end
    if isfield(settings, 'showChart')
        state.h.showChartCheck.Value = double(logical(settings.showChart));
    end
    if isfield(settings, 'chartSmoothWindow')
        w = round(settings.chartSmoothWindow);
        state.chartSmoothWindow = max(1, w);
        state.h.chartSmoothEdit.String = num2str(state.chartSmoothWindow);
    end
    fig.UserData = state;
end
