function ok = canReuseMainPlotGfx(gfx, sig)
ok = false;
if isempty(gfx) || ~isstruct(gfx) || isempty(gfx.signature)
    return;
end
if ~isequal(gfx.signature, sig)
    return;
end
if numel(gfx.traceLines) ~= sig.numChannels || ~all(isgraphics(gfx.traceLines))
    return;
end
ok = true;
end
