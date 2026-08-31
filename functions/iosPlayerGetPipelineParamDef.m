function def = iosPlayerGetPipelineParamDef(fieldName)
    defs = iosPlayerPipelineParamDefs();
    if strcmp(fieldName, 'contrast')
        def = defs(end);
        return
    end
    idx = find(strcmp({defs.stateField}, fieldName), 1);
    if isempty(idx)
        error('iosPlayerGetPipelineParamDef: unknown field %s', fieldName);
    end
    def = defs(idx);
end
