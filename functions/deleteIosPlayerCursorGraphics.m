function deleteIosPlayerCursorGraphics(cursor)
    if ~isempty(cursor.handle) && isvalid(cursor.handle)
        delete(cursor.handle);
        cursor.handle = [];
    end
    if isfield(cursor, 'textHandle') && ~isempty(cursor.textHandle) && isvalid(cursor.textHandle)
        delete(cursor.textHandle);
        cursor.textHandle = [];
    end
end
