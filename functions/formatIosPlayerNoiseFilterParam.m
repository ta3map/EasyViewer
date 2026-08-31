function s = formatIosPlayerNoiseFilterParam(state)
    if strcmp(state.noiseFilterType, 'highpass')
        s = sprintf('%.2f', state.noiseFilterParam);
        return
    end
    if strcmp(state.noiseFilterType, 'median') || strcmp(state.noiseFilterType, 'wiener')
        s = sprintf('%d', round(state.noiseFilterParam));
        return
    end
    s = sprintf('%.2f', state.noiseFilterParam);
end
