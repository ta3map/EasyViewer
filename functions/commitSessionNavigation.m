function commitSessionNavigation(sourceTag)
%COMMITSESSIONNAVIGATION Notify peers after chosen_time_interval changed.

    global matFilePath time

    if nargin < 1
        sourceTag = '';
    end
    if isempty(matFilePath) || isempty(time)
        return;
    end
    notifySessionPeers('navigation', sourceTag);
end
