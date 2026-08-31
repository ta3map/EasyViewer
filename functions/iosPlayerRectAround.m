function [rect, sizeValue] = iosPlayerRectAround(row, col, halfSize, frameSize)
    row_min = max(1, row - halfSize);
    row_max = min(frameSize(1), row + halfSize);
    col_min = max(1, col - halfSize);
    col_max = min(frameSize(2), col + halfSize);
    rect = [row_min, row_max, col_min, col_max];
    sizeValue = halfSize;
end
