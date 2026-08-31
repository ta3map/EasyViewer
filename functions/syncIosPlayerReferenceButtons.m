function syncIosPlayerReferenceButtons(fig)
    state = fig.UserData;
    visAdd = 'off';
    visDel = 'off';
    if state.iosMode
        visAdd = 'on';
        visDel = 'off';
        if ~isempty(state.referenceCursor)
            visAdd = 'off';
            visDel = 'on';
        end
    end
    state.h.addReferenceBtn.Visible = visAdd;
    state.h.deleteReferenceBtn.Visible = visDel;
    fig.UserData = state;
end
