function notifySessionPeers(event, sourceTag)
%NOTIFYSESSIONPEERS Notify other open Viewer/Analysis windows about session changes.

    if nargin < 2
        sourceTag = '';
    end

    peerTags = {'SignalViewerGUI', 'SignalAnalysisGUI'};
    for i = 1:numel(peerTags)
        tag = peerTags{i};
        if strcmp(tag, sourceTag)
            continue;
        end
        figs = findobj('Type', 'figure', 'Tag', tag);
        for j = 1:numel(figs)
            fig = figs(j);
            if ~isgraphics(fig)
                continue;
            end
            ud = get(fig, 'UserData');
            if ~isstruct(ud) || ~isfield(ud, event)
                continue;
            end
            cb = ud.(event);
            if isa(cb, 'function_handle')
                cb();
            end
        end
    end
end
