function state = setIosPlayerClickMode(state, mode, cursorIdx)
    state.awaitingClick = false;
    state.awaitingReferenceClick = false;
    state.editingCursorIndex = [];
    state.h.addCursorBtn.String = 'Add Cursor';
    state.h.addReferenceBtn.String = 'Add Reference';
    state.h.editCursorBtn.String = 'Edit Position';
    if strcmp(mode, 'idle')
        return
    end
    if strcmp(mode, 'addCursor')
        state.awaitingClick = true;
        state.h.addCursorBtn.String = 'Click on image...';
        return
    end
    if strcmp(mode, 'addReference')
        state.awaitingReferenceClick = true;
        state.h.addReferenceBtn.String = 'Click on image...';
        return
    end
    if strcmp(mode, 'edit')
        state.editingCursorIndex = cursorIdx;
        state.h.editCursorBtn.String = 'Click on image...';
    end
end
