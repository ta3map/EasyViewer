function power_decay_GUI
    % Create the GUI figure
    fig = figure('Position', [100, 100, 400, 300], 'Name', 'Inverse Log GUI Flipped', 'NumberTitle', 'off');

    % Create the slider
    slider = uicontrol('Style', 'slider', ...
                       'Min', 0, 'Max', 100, 'Value', 0, ...
                       'Position', [50, 200, 300, 20], ...
                       'Callback', @slider_callback);

    % Create text to display the slider value
    text_value = uicontrol('Style', 'text', ...
                           'Position', [150, 150, 100, 30], ...
                           'String', num2str(slider.Value));

    % Create axes for plotting
    axes('Position', [0.1, 0.3, 0.8, 0.5]);
    hPlot = plot(0, 0);
    xlabel('Slider Value');
    ylabel('Output Value');
    xlim([0 100]);
    ylim([95 100]);

    % Slider callback function
    function slider_callback(~, ~)
        input_val = slider.Value;
        output_val = 100 - (5 * (1 - log(1 + input_val) / log(101)));
        set(text_value, 'String', num2str(output_val));
        
        % Update plot
        x = linspace(0, 100, 100);
        y = 100 - (5 * (1 - log(1 + x) / log(101)));
        set(hPlot, 'XData', x, 'YData', y);
        hold on;
        plot(input_val, output_val, 'ro');
        hold off;
    end

    % Initialize plot
    slider_callback();
end
