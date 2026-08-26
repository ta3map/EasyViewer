function rel_times = eventRelativeTimes(ev1, ev2)
%EVENTRELATIVETIMES For each A event, delta to nearest B event.

    ev1 = ev1(:);
    ev2 = ev2(:);
    rel_times = zeros(numel(ev1), 1);
    for i = 1:numel(ev1)
        [~, closest_idx] = min(abs(ev2 - ev1(i)));
        rel_times(i) = ev1(i) - ev2(closest_idx);
    end
end
