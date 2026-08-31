function n20 = calculateIosPlayerN20Frames(meta)
    n20 = 1;
    if meta.dt > 0
        n20 = round(20 / meta.dt);
    end
end
