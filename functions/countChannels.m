function rChNum = countChannels(pf)

% if (pf(end) ~= '\')%no slash
%     pf(end + 1) = '\';
% end
% if ~exist(pf, 'dir') %&& ~exist(pf, 'file')
%     [~, pf] = uigetfile('*.ncs; *.nev; *.nse', 'Select file', pf);%open dialog
% end

% if isempty(strt), strt = 0; end %start from zeros
% if isempty(stp), stp = 'e'; end %read to follow out
    
rChNum = 0;%counter of channels
dirCnt = dir(pf);%directory content
ncsFiles(1:length(dirCnt)) = struct('f', '', 'bytes', []);
largestF = 1;%number of file (in ncsFiles structure) with largest size
for t = 1:length(dirCnt)
    if ((~dirCnt(t).isdir) && (length(dirCnt(t).name) > 3))%not directory and name good
        if isequal(dirCnt(t).name(end - 3:end), '.ncs')
            ch = str2double(dirCnt(t).name(4:(end - 4)));%number of channel (3-letteral name + number of channel)
            ncsFiles(ch).f = [pf, dirCnt(t).name];%full name of channel-file
            ncsFiles(ch).bytes = dirCnt(t).bytes;%size of file (bytes)
            if (ncsFiles(ch).bytes > ncsFiles(largestF).bytes)
                largestF = ch;%number of file (in ncsFiles structure) with largest size
            end
            rChNum = rChNum + 1;%increase counter of channels
        end
    end
end
ncsFiles((rChNum + 1):end) = [];%delet empty