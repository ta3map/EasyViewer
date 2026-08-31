function state = stopIosPlayerPlayback(state)
    if ~isempty(state.playTimer) && isvalid(state.playTimer)
        stop(state.playTimer);
        delete(state.playTimer);
        state.playTimer = [];
        state.h.playBtn.String = createIosPlayerIconButtonHTML(state.playIcon);
    end
    if state.isRecording && ~isempty(state.videoWriter) && isvalid(state.videoWriter)
        close(state.videoWriter);
        state.isRecording = false;
        state.videoWriter = [];
        state.h.recordBtn.String = createIosPlayerIconButtonHTML(state.recordIcon);
    end
end
