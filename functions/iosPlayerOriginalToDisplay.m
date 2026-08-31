function [x, y] = iosPlayerOriginalToDisplay(row, col, rotationAngle, offsetX, offsetY, zoomFactor, frameSize)
    H = frameSize(1);
    W = frameSize(2);
    cx = (W + 1) / 2;
    cy = (H + 1) / 2;
    angle_rad = -rotationAngle * pi / 180;
    col1 = (col - cx) * cos(angle_rad) - (row - cy) * sin(angle_rad) + cx;
    row1 = (col - cx) * sin(angle_rad) + (row - cy) * cos(angle_rad) + cy;
    col2 = col1 + offsetX;
    row2 = row1 + offsetY;
    x = (col2 - cx) * zoomFactor + cx;
    y = (row2 - cy) * zoomFactor + cy;
end
