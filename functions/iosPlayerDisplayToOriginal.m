function [row, col] = iosPlayerDisplayToOriginal(x, y, rotationAngle, offsetX, offsetY, zoomFactor, frameSize)
    H = frameSize(1);
    W = frameSize(2);
    cx = (W + 1) / 2;
    cy = (H + 1) / 2;
    angle_rad = rotationAngle * pi / 180;
    col2 = (x - cx) / zoomFactor + cx;
    row2 = (y - cy) / zoomFactor + cy;
    col1 = col2 - offsetX;
    row1 = row2 - offsetY;
    col = (col1 - cx) * cos(angle_rad) - (row1 - cy) * sin(angle_rad) + cx;
    row = (col1 - cx) * sin(angle_rad) + (row1 - cy) * cos(angle_rad) + cy;
end
