function data_out = removeStimArtifact(data_in, stims, time, win_r, method)
% Убираем артефакт стимула путем сглаженной интерполяции
% data_in - входные данные (столбец или матрица)
% stims - время стимулов (массив)
% time - временная ось
% win_r - половина окна удаления (в индексах)
% method - метод интерполяции: 'linear' (по умолчанию), 'spline', 'median', 'pchip', 'smooth'

if ~isnumeric(data_in) | ~isnumeric(stims) | ~isnumeric(time) | ~isnumeric(win_r)
    error('Все входные параметры должны быть числовыми');
end

if nargin < 5 || isempty(method)
    method = 'linear';
end

if isscalar(stims)
    stims = [stims];
end

wasTransposed = size(data_in, 2) > size(data_in, 1);
if wasTransposed
    data_in = data_in';
end

if size(time, 2) > size(time, 1)
    time = time';
end

data_out = data_in;
nSamples = size(data_in, 1);
method = lower(method);

if ~isempty(stims) & win_r ~= 0
    stim_inxs = ClosestIndex(stims, time, true);
    win_r = round(win_r);

    for i = 1:length(stim_inxs)
        start_inx = stim_inxs(i) - win_r;
        end_inx = stim_inxs(i) + win_r;

        if start_inx <= 1 | end_inx >= nSamples
            continue;
        end

        n_points = end_inx - start_inx + 1;

        switch method
            case 'pchip'
                extend_win = max(3, round(win_r * 0.5));
                left_extend = max(1, start_inx - extend_win);
                right_extend = min(nSamples, end_inx + extend_win);
                x_all = [time(left_extend:start_inx-1); time(end_inx+1:right_extend)];
                y_all = [data_in(left_extend:start_inx-1, :); data_in(end_inx+1:right_extend, :)];
                interpolated_vals = pchip(x_all, y_all, time(start_inx:end_inx));

            case 'spline'
                extend_win = max(3, round(win_r * 0.5));
                left_extend = max(1, start_inx - extend_win);
                right_extend = min(nSamples, end_inx + extend_win);
                x_all = [time(left_extend:start_inx-1); time(end_inx+1:right_extend)];
                y_all = [data_in(left_extend:start_inx-1, :); data_in(end_inx+1:right_extend, :)];
                interpolated_vals = spline(x_all, y_all, time(start_inx:end_inx));

            case 'smooth'
                w = linspace(0, 1, n_points)';
                linear_vals = data_in(start_inx-1, :) + (data_in(end_inx+1, :) - data_in(start_inx-1, :)) .* w;
                edge_points = max(3, round(n_points * 0.2));
                window = ones(n_points, 1);
                alphas = ((0:edge_points-1) / edge_points)';
                window(1:edge_points) = alphas;
                window(n_points-edge_points+1:n_points) = flipud(alphas);
                original_vals = data_in(start_inx:end_inx, :);
                interpolated_vals = linear_vals .* window + original_vals .* (1 - window);
                n_smooth = max(5, min(round(n_points/3), n_points));
                interpolated_vals = movmean(interpolated_vals, n_smooth, 1, 'Endpoints', 'shrink');

            case 'median'
                median_win = max(5, round(win_r * 0.5));
                left_data = data_in(max(1, start_inx - win_r - median_win):start_inx-1, :);
                right_data = data_in(end_inx+1:min(nSamples, end_inx + win_r + median_win), :);
                median_val = median([left_data; right_data], 1);
                interpolated_vals = repmat(median_val, n_points, 1);

            otherwise % linear
                w = linspace(0, 1, n_points)';
                interpolated_vals = data_in(start_inx-1, :) + ...
                    (data_in(end_inx+1, :) - data_in(start_inx-1, :)) .* w;
        end

        data_out(start_inx:end_inx, :) = interpolated_vals;
    end
end

if wasTransposed
    data_out = data_out';
end

end
