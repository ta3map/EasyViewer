function valid = iosPlayerHasValidMeta(fig)
    state = fig.UserData;
    valid = ~isempty(state.meta);
end
