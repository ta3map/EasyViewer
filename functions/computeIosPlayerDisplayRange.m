function [baseRange, state] = computeIosPlayerDisplayRange(displayFrame, rawFrame, state)
    percentileMin = 0.01;
    percentileMax = 99.99;
    if state.iosMode
        if isempty(state.climIosMin) || isempty(state.climIosMax) || state.climIosMax <= state.climIosMin
            state.climIosMin = prctile(displayFrame(:), percentileMin);
            state.climIosMax = prctile(displayFrame(:), percentileMax);
            center = (state.climIosMin + state.climIosMax) / 2;
            halfSpan = (state.climIosMax - state.climIosMin) / 2;
            halfSpan = max(halfSpan, 1e-4);
            state.climIosMin = center - halfSpan;
            state.climIosMax = center + halfSpan;
            state.h.iosMinEdit.String = sprintf('%.6f', state.climIosMin);
            state.h.iosMaxEdit.String = sprintf('%.6f', state.climIosMax);
        end
        state.climIosBase = [state.climIosMin state.climIosMax];
        baseRange = state.climIosBase;
        return
    end
    if isempty(state.clim) || (state.clim(1) == 0 && state.clim(2) == 65535)
        state.clim = [prctile(rawFrame(:), percentileMin) prctile(rawFrame(:), percentileMax)];
    end
    baseRange = state.clim;
end
