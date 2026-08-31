function updateIosPlayerCursorsTable(fig)
    state = fig.UserData;
    if isempty(state.cursors)
        state.h.cursorsTable.Data = cell(0, 5);
    else
        numCursors = length(state.cursors);
        data = cell(numCursors, 5);
        for i = 1:numCursors
            cursor = state.cursors(i);
            if ~isfield(cursor, 'visible')
                cursor.visible = true;
                state.cursors(i) = cursor;
            end
            if ~isfield(cursor, 'size')
                cursor.size = 10;
                state.cursors(i) = cursor;
            end
            data{i, 1} = i;
            data{i, 2} = cursor.center(1);
            data{i, 3} = cursor.center(2);
            data{i, 4} = cursor.size;
            data{i, 5} = cursor.visible;
        end
        state.h.cursorsTable.Data = data;
    end
    fig.UserData = state;
end
