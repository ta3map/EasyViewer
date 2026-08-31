function syncIosPlayerSliderEdit(fig, ax, fieldName, sourceType)
    state = fig.UserData;
    def = iosPlayerGetPipelineParamDef(fieldName);
    if strcmp(sourceType, 'slider')
        value = double(state.h.(def.sliderKey).Value);
        if def.round
            value = round(value);
        end
    else
        value = str2double(state.h.(def.editKey).String);
        if isempty(def.stateField)
            currentValue = state.h.(def.sliderKey).Value;
        else
            currentValue = state.(def.stateField);
        end
        if isnan(value)
            state.h.(def.editKey).String = sprintf(def.format, currentValue);
            return
        end
        if def.editRejectBelowMin && (value < def.min || value > def.max)
            state.h.(def.editKey).String = sprintf(def.format, currentValue);
            return
        end
        if strcmp(fieldName, 'gaussianSigma') && value < 0
            state.h.(def.editKey).String = sprintf(def.format, currentValue);
            return
        end
        value = max(def.min, min(def.max, value));
        if def.round
            value = round(value);
        end
    end
    state = applyIosPlayerPipelineParam(state, fieldName, value);
    if def.clearBaseframe
        state = clearIosPlayerBaseframe(state);
    end
    fig.UserData = state;
    iosPlayerRefreshAfterParamChange(fig, ax, def.refreshMode);
end

function iosPlayerRefreshAfterParamChange(fig, ax, refreshMode)
    if strcmp(refreshMode, 'frame')
        refreshIosPlayerView(fig, ax);
        return
    end
    if strcmp(refreshMode, 'contrast')
        state = fig.UserData;
        if ~iosPlayerHasValidMeta(fig)
            return
        end
        if isempty(state.him) || ~isvalid(state.him)
            return
        end
        applyIosPlayerContrast(ax, getIosPlayerBaseRange(state), state.h.contrastSlider.Value);
    end
end
