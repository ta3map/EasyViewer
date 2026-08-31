function baseRange = getIosPlayerBaseRange(state)
    ranges = {state.clim, state.climIosBase};
    idx = 1 + double(~isempty(state.climIosBase));
    baseRange = ranges{idx};
end
