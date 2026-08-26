function indexGrid = matchChannelLayout(nameGrid, channelNames, channelEnabled)
%MATCHCHANNELLAYOUT Map layout name cells to 1-based channel indices.
% 0 = empty / not found / disabled.

    [nRows, nCols] = size(nameGrid);
    indexGrid = zeros(nRows, nCols);

    namesNorm = cellfun(@normalizeChannelToken, channelNames, 'UniformOutput', false);
    nCh = numel(channelNames);

    for r = 1:nRows
        for c = 1:nCols
            token = nameGrid{r, c};
            if isempty(token)
                continue;
            end
            chIdx = resolveChannelIndex(token, namesNorm, nCh);
            if chIdx < 1
                continue;
            end
            if ~channelEnabled(chIdx)
                continue;
            end
            indexGrid(r, c) = chIdx;
        end
    end
end

function chIdx = resolveChannelIndex(token, namesNorm, nCh)
    chIdx = 0;
    tokenNorm = normalizeChannelToken(token);
    if isempty(tokenNorm)
        return;
    end

    numVal = str2double(tokenNorm);
    if ~isnan(numVal) && numVal == floor(numVal) && numVal >= 1 && numVal <= nCh
        chIdx = numVal;
        return;
    end

    match = find(strcmp(namesNorm, tokenNorm), 1, 'first');
    if ~isempty(match)
        chIdx = match;
    end
end

function out = normalizeChannelToken(token)
    out = '';
    if isempty(token)
        return;
    end
    out = lower(strtrim(char(token)));
end
