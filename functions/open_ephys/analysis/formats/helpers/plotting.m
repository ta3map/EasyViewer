function plotContinuousWithSpikes(handle, stream, spikes)

    t = spikes.timestamps;
    tx = [t.';t.';nan(1,length(t))];
    ymin = double(min(stream.samples(1,:))).*ones(1,length(t));
    ymax = double(max(stream.samples(1,:))).*ones(1,length(t));
    ty = [ymin;ymax;nan(1,length(t))];

    plot(handle, stream.samples(1,:)); hold on;
    plot(handle, tx(:),ty(:));

end

function plotContinuousWithEvents(handle, stream, events)


    t = events.timestamp;
    tx = [t.';t.';nan(1,length(t))];
    ymin = double(min(stream.samples(1,:))).*ones(1,length(t));
    ymax = double(max(stream.samples(1,:))).*ones(1,length(t));
    ty = [ymin;ymax;nan(1,length(t))];

    plot(handle, stream.samples(1,:)); hold on;
    plot(handle, tx(:),ty(:));
    
end