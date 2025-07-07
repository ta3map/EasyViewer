# Easy Viewer

[🇬🇧 English](README.md) | [🇷🇺 Русский](README_RU.md)

A program for viewing and analyzing electrophysiological signals

- [Getting Started](#getting-started)
	- [Opening a ZAV file](#opening-a-zav-file)
	- [Opening an EV file](#opening-an-ev-file)
	- [Viewing signals](#viewing-signals)
- [Event Management](#event-management)
	- [Adding events](#adding-events)
		- [Manual event addition settings](#manual-event-addition-settings)
	- [Automatic event detection](#automatic-event-detection)
	- [Average trace by events](#average-trace-by-events)
	- [Saving events](#saving-events)
	- [Deleting events](#deleting-events)
- [Signal Processing](#signal-processing)
	- [Filtering](#filtering)
	- [Average subtraction](#average-subtraction)
	- [CSD display](#csd-display)
- [Additional Features](#additional-features)
	- [Converting to ZAV format](#converting-to-zav-format)
	- [File manager](#file-manager)
	- [Channel settings](#channel-settings)
	- [Hiding the sidebar](#hiding-the-sidebar)

## Main signal viewing window
The main window displays multi-channel LFP signals. Users can observe signal activity in different channels and visually analyze the signals.

![Main viewing window](https://github.com/ta3map/EasyViewer/blob/main/images//MainWindow.PNG)

## Getting Started

### Opening a ZAV file
To start viewing, click the **Load .mat File (ZAV Format)** button or select **File/open ZAV (.mat) file**. Then in the selection window that appears, find the mat-file you're interested in.
If the file has never been opened before, by default the signal will be displayed on all channels. If desired, the display can be changed (see [Channel settings](#channel-settings))

See also: [File manager](#file-manager), [Converting to ZAV format](#converting-to-zav-format)

### Opening an EV file
If events have been detected and saved in .ev format for the experiment (see [Saving events](#saving-events)), you can start working by opening the ev-file. To do this, click the **Load Events** button or select **File/open event (.ev) file**.
A window will open for selecting ev-files. After selection, LFP data for the corresponding events and the events themselves will be loaded (see [Event Management](#event-management)).

### Viewing signals
The time control panel allows you to select the time range of interest for detailed viewing, as well as quickly navigate between different data segments.

The menu has a slider for scrolling through time, and there are also buttons for paging through.

The time scale menu contains measurement units: seconds (s), milliseconds (ms) and minutes (min). The units displayed on the time axis are always set accordingly to the selection.

![Scrolling](https://github.com/ta3map/EasyViewer/blob/main/images/time1.PNG)

The time windows before and after the current time point set the range of the given signal section.

![Display range](https://github.com/ta3map/EasyViewer/blob/main/images/time2.PNG)

- `Fs` - sampling frequency of the displayed signal;

- `Ch.Shift` - the gap value between channels in units corresponding to the LFP signal;

- `CSD` - selection of CSD display;

- `MUA` - selection of MUA display;

- `MUA coef` - sets the MUA display threshold in relative units.

![Additional Functions](https://github.com/ta3map/EasyViewer/blob/main/images/time3.PNG)

## Event Management
At the bottom of the left panel are tools for adding, deleting and automatically detecting events on the LFP signal, as well as for saving and loading these events.

![Event menu](https://github.com/ta3map/EasyViewer/blob/main/images/EventMenu.PNG)

### Adding events

To mark an event, use the **Add Event** button or hold **Ctrl** and click on the desired section of the graph.

#### Manual event addition settings

![Manual event addition settings](https://github.com/ta3map/EasyViewer/blob/main/images/manualevent.PNG)

Manual event addition allows users to define points of interest using the following parameters:

- **Detection Mode**: Choose `manual` for direct event addition at the specified time point or `locked` to correct the event position relative to a local extremum in the specified time window.

- **Channel Number**: Specify the channel in which the event needs to be added. In the example, `Ch 35` is selected.

- **Polarity**: The polarity choice determines whether the system will look for a maximum or minimum in the channel signal depending on whether the value is set to `positive` or `negative`.

- **Time Window**: Set the time window in milliseconds within which the program will search for a local extremum when the `locked` mode is selected.

After setting the parameters, click `Save` to apply them. In `manual` mode, the marker will be added directly at the selected point, while in `locked` mode, the program will first identify the most significant point (maximum or minimum) in the selected range before placing the event marker.

#### Automatic event detection

This tool allows automatic detection of significant events, such as peaks or troughs, in electrophysiological signals. Access to this functionality is available through the `Auto Event Detection` button in the main program window or through the menu `Options/Auto Event Detection`.

![Automatic event detection](https://github.com/ta3map/EasyViewer/blob/main/images/autodetector.PNG)

##### Main event detector parameters:

- **Detection Type**: You can choose the type of event detection depending on your analysis. For single channel analysis, use the 'one channel positive' and 'one channel negative' parameters.
If you need to base detection on activity on two channels, you should choose 'two channels' modes.

- **Minimal Peak Amplitude**: Sets the minimum amplitude threshold for peak detection. Only events with amplitude above this value will be detected.

- **Positive Channel** and **Negative Channel**: Channel selection for comparison if 'two channels difference' mode is selected. This allows detecting events based on the difference in activity between two channels.

- **Minimal Time Between Peaks**: Sets the minimum time between detected peaks to exclude false triggers related to closely spaced events.

- **Smooth Coefficient**: Parameter for smoothing the signal before peak detection, which helps reduce the influence of noise.

- **Detection Mode**: Allows you to choose whether peaks/troughs (peaks) or signal onsets will be detected.

After setting the parameters, pressing the `Check Detection` button allows you to preview potential events on the signal graph, which gives the opportunity to visually confirm the correctness of the settings before applying them.

The `Apply` button is used to start the event detection process with the selected settings, after which events will be added to the program's event table for further analysis.

#### Average trace by events
- The `Mean Events` button allows you to build a trace consisting of LFP signal averaged around the event.

Example below:

![Result of averaging around events](https://github.com/ta3map/EasyViewer/blob/main/images/meanevents.PNG)

Display parameters for the average trace such as CSD or MUA depend on the settings and checkboxes in the main window. That is, if a certain time window range is selected, CSD or MUA mode is selected, then the averaged result will be in the same view.

#### Saving events
- The `Save Events` button allows you to save the entire current list of events. When saving, the user can specify the file name and choose the save path.

### Deleting events

#### Deleting an individual event
- By selecting an event from the list, you can use the `Delete Event` button to delete a specific event.
This allows you to clean the list of erroneously added or irrelevant events.

#### Clearing the event table
- The `Clear Table` button completely clears the event table.
This can be used to start a new observation session without old data.

### Working with the list
- The event list displays timestamps (`Time`) and comments (`Comment`) that can be added by the user for each event.
- The `Add Event`, `Delete Event` and `Clear Table` buttons are located under the table.

## Signal Processing

### Filtering

To open filtering settings, select **Options/Filtering**

![Filtering](https://github.com/ta3map/EasyViewer/blob/main/images/filtration_bandpass.PNG)

#### Channel selection
On the left is a panel where the user can activate or deactivate filtering for each channel (Ch 1 - Ch ...). Checkboxes allow you to control which channels will be filtered.

#### Filter parameters
Filter parameters are displayed on the right:
- Filter type (`bandpass` in the screenshot) can be selected from a dropdown list, which may include, for example, bandpass, lowpass and highpass filters.
- Filter frequency thresholds are set in the input fields for the lower (`100 Hz`) and upper (`200 Hz`) boundaries.
- Filter order (`4` in the screenshot) determines the steepness of the filter slope.

#### Filtering control
- The `Select ALL` and `Deselect ALL` buttons allow you to quickly select all channels or deselect all channels respectively.
- The `Check Filtration` button allows you to preview the filtering effect on the signal's frequency response.
- The `Apply` and `Cancel` buttons apply the filtering settings to the selected channels or cancel the changes.

#### Frequency response graph
At the bottom of the window is a graph showing the filter's frequency response (`Frequency Response`). This graph helps visualize the effects that the filter has on the signal, demonstrating amplification or suppression in different frequency ranges.

### Average subtraction

To open average subtraction settings, select **Options/Average subtraction**

![Average subtraction](https://github.com/ta3map/EasyViewer/blob/main/images/average_subtr.PNG)

#### Channel selection for processing
- The left side of the window contains a list of available channels (Ch 1 - Ch ...), for each of which you can enable or disable the application of the average subtraction function.
- Checkboxes (`Enabled`) allow you to select individual channels to which this processing will be applied.

#### Channel selection control
- Using the `Select ALL` and `Deselect ALL` buttons, the user can quickly select all channels or cancel the selection from all channels respectively for applying the function.

#### Applying settings
- After the necessary channels are selected, clicking the `Apply` button applies the average subtraction function to the selected channels.
Average subtraction helps eliminate background noise common to all channels.

### CSD display
To open CSD display settings, select **Options/CSD Displaying**

![CSD display](https://github.com/ta3map/EasyViewer/blob/main/images/CSD_settings.PNG)

The CSD function is used to visualize the spatial distribution of current sources and sinks based on recorded LFP data.

#### Channel selection
- The left panel contains a list of channels (Ch 1 - Ch ...) with checkboxes that allow you to enable or disable CSD display for each individual channel.
- Users can configure which channels will have CSD calculated and displayed, including or excluding them from the analysis.

#### Quick channel management
- The `Select ALL` and `Deselect ALL` buttons provide quick selection of all channels for inclusion in CSD analysis or exclusion of all channels respectively.

#### Visualization parameter adjustment
- The `Contrast Coef.` field is intended for adjusting the contrast coefficient when displaying CSD data, allowing you to improve the distinction between areas of high and low activity.
- The `Smooth Coef.` field provides the ability to adjust the smoothing coefficient, which can be used to reduce noise and improve the overall readability of CSD data.

#### Applying settings
- After setting the necessary parameters, the `Apply` button is used to apply CSD settings to the selected channels and update the data visualization.

# Additional Features

## Converting to ZAV format
This tool is designed to convert electrophysiological recording data from NeuraLynx format to ZAV mat-file format, which is compatible with the LFP signal viewing system.
To open conversion settings, select **File/convert NLX to ZAV**

![Converting to ZAV format](https://github.com/ta3map/EasyViewer/blob/main/images/zavconvert.PNG)

### Record path selection
- The `Select Record Path` button allows the user to select a folder containing NeuraLynx (.nlx) files that need to be converted.

### Conversion options
- The `Detect MUA` (multi-unit activity) checkbox activates the multi-unit activity detection function during conversion.
- The `threshold (n*STD)` field allows you to set the threshold in multiples of standard deviation for MUA detection.
  
### Channel selection
- The ability to select `all channels` indicates that conversion will be applied to all channels in the selected recording.
- The user can also specify specific channels for conversion if a more targeted approach is required.

### Sampling frequency setting
- The `Fs, Hz` (sampling frequency) field allows the user to set the desired sampling frequency for the output data. The default value is set to `1000 Hz`.

### Initiating the conversion process
- The `Start Conversion` button starts the data conversion process. After clicking, conversion will begin and progress will be displayed to the user.

## File manager 
The file manager is designed for navigating files placed in the list.
To open, click the `File manager` button or select **File/file manager**. 

### Loading the file list
In the opened `File manager` window, select `Load list`, a window will appear for selecting a table in **xlsx** format in which the file paths should be located. 

Then you need to select in which column the paths to the files of interest are located. In the example below, this is the `event path` item.

![File manager, column selection](https://github.com/ta3map/EasyViewer/blob/main/images/FM_select_column.PNG)

After selecting the column, you will see the loaded list

![File manager, loaded list](https://github.com/ta3map/EasyViewer/blob/main/images/FM_ready.PNG)

This can be a list with direct paths, as in the example. But you can also specify only the names of ev-files. In this case, the search for the file itself will be carried out inside the directory in which the list itself is located.

### Opening a file from the file manager

To open a file, click once on the line with the file and click `Open file`.

### Additional file manager features

You can save the list in **xlsx** format by clicking the `Save list` button.
You can delete an unnecessary file from the list by clicking the `Delete file` button.
You can add a new file to the list by clicking the `Add file` button.

### Channel settings
The channel settings sidebar provides the ability to select displayed channels, scaling and color changes for better visual distinction of signals.

![Channel settings](https://github.com/ta3map/EasyViewer/blob/main/images/ChannelSettings.PNG)

## Hiding the sidebar
By selecting the `hide Channel Settings` item in the `View` menu, you will hide the sidebar with channel information. This will increase the size of the LFP signal viewing window.

![View menu](https://github.com/ta3map/EasyViewer/blob/main/images/hideMenu.png)

Then clicking on `show Channel Settings` in the `View` menu will return the sidebar. 