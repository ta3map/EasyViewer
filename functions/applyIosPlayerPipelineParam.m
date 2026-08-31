function state = applyIosPlayerPipelineParam(state, fieldName, value)
    def = iosPlayerGetPipelineParamDef(fieldName);
    if def.round
        value = round(value);
    end
    value = max(def.min, min(def.max, value));
    if ~isempty(def.stateField)
        state.(def.stateField) = value;
    end
    state.h.(def.sliderKey).Value = value;
    state.h.(def.editKey).String = sprintf(def.format, value);
end
