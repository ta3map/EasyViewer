function nlxPrm = NlxParametr(headCell, fieldNm)
%get value of specified parameter
%
%INPUTS
%cscHd - cell array wiht Neuralynx parameter
%fieldNm - name of requested parameter (single name)
%
%OUTPUTS
%nlxPrm - value of parameter

nlxPrm = [];%initialization
for n = 1:length(headCell) %run over cells with parameters
    if ~isempty(strfind(headCell{n}, fieldNm))%string contains requested name
        t = find(headCell{n} == ' ', 1, 'first');%find delimiter
        strVal = headCell{n}((t + 1):end);%string with value of parameter
        if (any(double(strVal) < 46) || any(double(strVal) > 57))%value is word
            nlxPrm = strVal;
        else%value is numeric
            nlxPrm = str2double(strVal);%numeric value of parameter
        end
        break;%out of (for n)
    end
end
