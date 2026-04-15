function nlx_to_zav_streaming(recordPath, zavFilePath, channels_list, ncsFilePaths, lfp_Fs, detectMua, mua_std_coef, doResample, hWaitBar)
    channels_n = numel(channels_list);
    conversion_tic = tic;
    formatEta = @(sec) sprintf('~%d min %d s left', floor(sec / 60), round(rem(sec, 60)));

    m = matfile(zavFilePath, 'Writable', true);
    spks(channels_n) = struct('tStamp', [], 'ampl', [], 'shape', []);
    lfpVar = zeros(1, channels_n);
    hd = [];

    for ch_inx = 1:channels_n
        if ch_inx == 1
            [data, ~, hd_one] = ZavNrlynx2(recordPath, [], channels_list(1), [], [], ncsFilePaths(1));
            orig_Fs = 1e6 / hd_one.si;
            if doResample
                lfp_length = floor(size(data, 1) * lfp_Fs / orig_Fs);
            else
                lfp_length = size(data, 1);
            end
            waitbar(0, hWaitBar, 'Initializing MAT file...');
            m.lfp(lfp_length, channels_n) = single(0);
            hd = hd_one;
            hd.nADCNumChannels = channels_n;
        else
            [data, ~, hd_one] = ZavNrlynx2(recordPath, [], channels_list(ch_inx), [], [], ncsFilePaths(ch_inx));
            hd.adBitVolts = [hd.adBitVolts; hd_one.adBitVolts];
            hd.dspDelay_mks = [hd.dspDelay_mks; hd_one.dspDelay_mks];
            hd.adBitVoltsSpk = [hd.adBitVoltsSpk; hd_one.adBitVoltsSpk];
            hd.dspDelay_mksSpk = [hd.dspDelay_mksSpk; hd_one.dspDelay_mksSpk];
            hd.alignmentPt = [hd.alignmentPt; hd_one.alignmentPt];
            hd.inverted = [hd.inverted; hd_one.inverted];
            hd.recChUnits = [hd.recChUnits; hd_one.recChUnits];
            hd.recChNames = [hd.recChNames; hd_one.recChNames];
            hd.ch_si = [hd.ch_si; hd_one.ch_si];
        end

        data_col = data(:);

        hd_ch.adBitVolts = hd_one.adBitVolts(1);
        hd_ch.dspDelay_mks = hd_one.dspDelay_mks(1);
        hd_ch.si = hd_one.si;
        hd_ch.fADCSampleInterval = hd_one.fADCSampleInterval;
        hd_ch.recChNames = hd_one.recChNames(1);
        hd_ch.recChUnits = hd_one.recChUnits(1);
        hd_ch.inTTL_timestamps = hd_one.inTTL_timestamps;

        if detectMua
            [tStamp, ampl, shape] = detectMUAzav(data_col, hd_ch, mua_std_coef, true);
            spks(ch_inx).tStamp = single(tStamp);
            spks(ch_inx).ampl = single(ampl);
            spks(ch_inx).shape = shape;
        else
            spks(ch_inx).tStamp = single([]);
            spks(ch_inx).ampl = single([]);
            spks(ch_inx).shape = [];
        end

        if doResample
            data_processed = resample1(data_col, lfp_Fs, orig_Fs);
        else
            data_processed = data_col;
        end
        data_processed = data_processed(:);

        if length(data_processed) > lfp_length
            data_processed = data_processed(1:lfp_length);
        elseif length(data_processed) < lfp_length
            data_processed = [data_processed; zeros(lfp_length - length(data_processed), 1)];
        end

        lfpVar(ch_inx) = std(data_processed) / 10;
        m.lfp(:, ch_inx) = single(data_processed);

        elapsed = toc(conversion_tic);
        remain_sec = (ch_inx > 0) * (elapsed / ch_inx) * (channels_n - ch_inx);
        waitbar(ch_inx / channels_n, hWaitBar, sprintf('%d/%d: Channel %d %s', ch_inx, channels_n, ch_inx, formatEta(remain_sec)));
        clear data;
    end

    hd.chNumList = channels_list(:)';

    waitbar(0.95, hWaitBar, 'Finalizing data...');
    lfpVar = np_flatten(lfpVar)';

    if doResample
        actual_Fs = lfp_Fs;
        skip_points = orig_Fs / lfp_Fs;
    else
        actual_Fs = orig_Fs;
        skip_points = 1;
    end

    chnlGrp = {};
    zavp.file = recordPath;
    zavp.siS = 1 / actual_Fs;
    zavp.dwnSmplFrq = actual_Fs;
    zavp.stimCh = nan;

    if size(hd.inTTL_timestamps, 2) > 0
        if doResample
            r_i = (hd.inTTL_timestamps.t(:, 1) / hd.si) * (lfp_Fs / orig_Fs);
            f_i = (hd.inTTL_timestamps.t(:, 2) / hd.si) * (lfp_Fs / orig_Fs);
        else
            r_i = hd.inTTL_timestamps.t(:, 1) / hd.si;
            f_i = hd.inTTL_timestamps.t(:, 2) / hd.si;
        end
    else
        r_i = [];
        f_i = [];
    end
    zavp.realStim.r = r_i;
    zavp.realStim.f = f_i;
    zavp.rarStep = hd.ch_si' * 0 + skip_points;

    m.chnlGrp = chnlGrp;
    m.hd = hd;
    m.lfpVar = lfpVar;
    m.spks = spks;
    m.zavp = zavp;

    waitbar(1, hWaitBar, 'Complete');
end
