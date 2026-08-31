function out = applyIosPlayerGeometry(frame, rotationAngle, offsetX, offsetY, zoomFactor)
    out = frame;
    out = applyRotation(out, rotationAngle);
    out = applyOffset(out, offsetX, offsetY);
    out = applyZoom(out, zoomFactor, size(frame));
end

function out = applyRotation(frame, angleDeg)
    if angleDeg == 0
        out = frame;
        return
    end
    out = imrotate(frame, angleDeg, 'bilinear', 'crop');
end

function out = applyOffset(frame, offsetX, offsetY)
    if offsetX == 0 && offsetY == 0
        out = frame;
        return
    end
    out = imtranslate(frame, [offsetX, offsetY], 'OutputView', 'same');
end

function out = applyZoom(frame, zoomFactor, origSize)
    if zoomFactor == 1
        out = frame;
        return
    end
    H = origSize(1);
    W = origSize(2);
    resized = imresize(frame, zoomFactor, 'bilinear');
    [Hr, Wr] = size(resized);
    if Hr >= H && Wr >= W
        r0 = floor((Hr - H) / 2) + 1;
        c0 = floor((Wr - W) / 2) + 1;
        out = resized(r0:(r0 + H - 1), c0:(c0 + W - 1));
    else
        out = zeros(H, W, 'like', frame);
        r0 = floor((H - Hr) / 2) + 1;
        c0 = floor((W - Wr) / 2) + 1;
        out(r0:(r0 + Hr - 1), c0:(c0 + Wr - 1)) = resized;
    end
end
