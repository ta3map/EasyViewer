function filtered = applyIosPlayerFilters(img, filterType, param)
    switch filterType
        case 'gaussian'
            filtered = applyGaussian(img, param);
        case 'median'
            filtered = applyMedian(img, param);
        case 'wiener'
            filtered = applyWiener(img, param);
        case 'highpass'
            filtered = applyHighpass(img, param);
        otherwise
            filtered = img;
    end
end

function filtered = applyGaussian(img, sigma)
    if sigma <= 0
        filtered = img;
        return
    end
    if exist('imgaussfilt', 'file') == 2
        filtered = imgaussfilt(img, sigma);
    else
        hsize = max(3, 2 * ceil(3 * sigma) + 1);
        h = fspecial('gaussian', hsize, sigma);
        filtered = conv2(img, h, 'same');
    end
end

function filtered = applyMedian(img, windowSize)
    if windowSize < 3
        filtered = img;
        return
    end
    windowSize = round(windowSize);
    if mod(windowSize, 2) == 0
        windowSize = windowSize + 1;
    end
    if exist('medfilt2', 'file') == 2
        filtered = medfilt2(img, [windowSize windowSize]);
    else
        filtered = img;
    end
end

function filtered = applyWiener(img, windowSize)
    if windowSize < 3
        filtered = img;
        return
    end
    windowSize = round(windowSize);
    if mod(windowSize, 2) == 0
        windowSize = windowSize + 1;
    end
    if exist('wiener2', 'file') == 2
        filtered = wiener2(img, [windowSize windowSize]);
    else
        filtered = img;
    end
end

function filtered = applyHighpass(img, sigma)
    if sigma <= 0
        filtered = img;
        return
    end
    lowpass = applyGaussian(img, sigma);
    filtered = img - lowpass;
end
