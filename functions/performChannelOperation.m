function resultDataMat = performChannelOperation(lfpMatrix, idxA, idxB, opStr, sumA, sumB)
%PERFORMCHANNELOPERATION Element-wise channel-group arithmetic on LFP matrix.

    dataA = lfpMatrix(:, idxA);
    dataB = lfpMatrix(:, idxB);

    if sumA
        dataA = sum(dataA, 2);
    end
    if sumB
        dataB = sum(dataB, 2);
    end

    if ~sumA && numel(idxA) > 1
        dataA = mat2cell(dataA, size(dataA, 1), ones(1, size(dataA, 2)));
    else
        dataA = {dataA};
    end
    if ~sumB && numel(idxB) > 1
        dataB = mat2cell(dataB, size(dataB, 1), ones(1, size(dataB, 2)));
    else
        dataB = {dataB};
    end

    numChannelsA = numel(dataA);
    numChannelsB = numel(dataB);
    maxChannels = max(numChannelsA, numChannelsB);
    if numChannelsA < maxChannels
        dataA(end+1:maxChannels) = dataA(end);
    end
    if numChannelsB < maxChannels
        dataB(end+1:maxChannels) = dataB(end);
    end

    resultData = cell(1, maxChannels);
    for i = 1:maxChannels
        switch opStr
            case 'A + B'
                resultData{i} = dataA{i} + dataB{i};
            case 'A - B'
                resultData{i} = dataA{i} - dataB{i};
            case 'A * B'
                resultData{i} = dataA{i} .* dataB{i};
            case 'A / B'
                resultData{i} = dataA{i} ./ dataB{i};
            otherwise
                error('performChannelOperation:UnknownOp', 'Invalid operation: %s', opStr);
        end
    end
    resultDataMat = cell2mat(resultData);
end
