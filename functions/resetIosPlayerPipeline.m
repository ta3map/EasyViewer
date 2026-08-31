function state = resetIosPlayerPipeline(state)
    defaults = iosPlayerDefaultPipelineState();
    defs = iosPlayerPipelineParamDefs();
    for i = 1:numel(defs)
        if isempty(defs(i).stateField)
            continue
        end
        state = applyIosPlayerPipelineParam(state, defs(i).stateField, defaults.(defs(i).stateField));
    end
    state.noiseFilterType = defaults.noiseFilterType;
    state.noiseFilterParam = defaults.noiseFilterParam;
    state.h.noiseFilterPopup.Value = 1;
    state = applyIosPlayerNoiseFilterUi(state, state.noiseFilterType);
    state = clearIosPlayerBaseframe(state);
end
