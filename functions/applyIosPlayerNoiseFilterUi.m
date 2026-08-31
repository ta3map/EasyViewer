function state = applyIosPlayerNoiseFilterUi(state, filterType)
    cfg = iosPlayerNoiseFilterConfig(filterType);
    if ~cfg.visible
        state.h.blurSigmaText.Visible = 'off';
        state.h.blurSigmaSlider.Visible = 'off';
        state.h.blurSigmaEdit.Visible = 'off';
        return
    end
    state.h.blurSigmaText.Visible = 'on';
    state.h.blurSigmaSlider.Visible = 'on';
    state.h.blurSigmaEdit.Visible = 'on';
    state.h.blurSigmaText.String = cfg.label;
    state.h.blurSigmaSlider.Min = cfg.min;
    state.h.blurSigmaSlider.Max = cfg.max;
    if state.noiseFilterParam < cfg.min
        state.noiseFilterParam = cfg.defaultParam;
    end
    state.h.blurSigmaSlider.Value = state.noiseFilterParam;
    state.h.blurSigmaEdit.String = formatIosPlayerNoiseFilterParam(state);
end

function cfg = iosPlayerNoiseFilterConfig(filterType)
    cfg = struct('label', '', 'min', 1, 'max', 1000, 'defaultParam', 5, 'visible', false);
    if strcmp(filterType, 'none')
        return
    end
    cfg.visible = true;
    if strcmp(filterType, 'highpass')
        cfg.label = 'Sigma:';
        cfg.min = 0.1;
        cfg.max = 1000;
        cfg.defaultParam = 3.0;
        return
    end
    cfg.label = 'Kernel size:';
    cfg.min = 3;
    cfg.max = 1000;
    cfg.defaultParam = 5;
end
