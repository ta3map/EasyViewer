# Events and Stimuli

Managing events and stimuli is a key function of the program for analyzing electrophysiological data.

## Events

Events represent timestamps of significant moments in the signal (peaks, dips, onsets, etc.).

### Events Table

The events table is displayed in the lower part of the Signal Viewer side panel. Contains columns:

- **Time** - event timestamp
- **Comment** - event comment

![Events table](screenshots/events_table.png)

### Adding Event

#### Simple Addition

- Press the **Add Event** button below the events table
- Or hold **Ctrl** and click the mouse on the graph at the desired point

The event is added at the specified time point.

#### Addition with Settings

Menu **Options/Manual events settings** opens the settings window:

- **Detection Mode**:
  - **manual** - event is added at the specified point
  - **locked** - event is corrected to local extremum
- **Channel Number** - channel number for adding event
- **Polarity** - extremum search polarity (positive/negative)
- **Time Window** - extremum search time window in milliseconds (for locked mode)

In **locked** mode, the program searches for a local extremum (maximum or minimum depending on polarity) in the specified time window and places the event at the found point.

![Manual event addition settings](screenshots/manual_event_settings.png)

### Automatic Event Detection

Menu **Analysis/Autodetection** or **Auto Event Detection** button opens the automatic detection window.

**Detection parameters:**

- **Detection Type**:
  - **one channel positive** - detection of positive peaks on one channel
  - **one channel negative** - detection of negative peaks on one channel
  - **two channels difference** - detection based on difference between two channels
- **Minimal Peak Amplitude** - minimum peak amplitude
- **Positive Channel** / **Negative Channel** - channels for two channels mode
- **Minimal Time Between Peaks** - minimum time between peaks
- **Smooth Coefficient** - signal smoothing coefficient
- **Detection Mode** - peaks or onsets

**Usage:**

1. Configure detection parameters
2. Press **Check Detection** for preliminary preview
3. Press **Apply** to apply detection and add events to the table

![Automatic event detection](screenshots/auto_detection.png)

### Editing Events

Menu **Options/Edit events** opens the events editing window. Allows:

- Changing event timestamps
- Changing event comments
- Deleting events

![Editing events](screenshots/edit_events.png)

### Deleting Event

- Select an event in the table (enter the number in the field below the table)
- Press the **Delete Event** button

The **Clear Table** button removes all events from the table.

### Importing Events from Stimuli

Menu **Options/Import events from stimulus** creates events based on stimulus timestamps.

### Saving and Loading Events

Events are automatically saved when saving a ZAV file. For separate saving, use the **Save Events** button below the events table.

Events are loaded when opening an EV file or ZAV file with saved events.

## Stimuli

Stimuli represent timestamps of stimulus delivery in the experiment.

### Stimuli Table

Stimuli are displayed in the middle part of the Signal Viewer side panel. The list shows stimulus timestamps.

![Stimuli table](screenshots/stimuli_table.png)

### Editing Stimuli

The **Edit** button next to the "Stimuli" header or menu **Options/Edit stimulus times** opens the stimulus timestamp editing window.

![Editing stimuli](screenshots/edit_stimuli.png)

### Hiding Stimuli

Menu **View/Hide stimulus** hides or shows stimulus display on the graph.

### Automatic Stimulus Detection

The **autoDetectStimuli** module can automatically detect stimuli in the signal. Used through File Manager.

### Loading Stimuli from Settings

Stimuli can be loaded from the channel settings file (`*_channelSettings.stn`) when opening a file, if the `stims_loaded_from_settings` flag is set.

## Mean Trace by Events

Menu **Options/Mean Events** opens the settings window for averaging signal around events.

**Parameters:**

- **Time Window** - time window around event
- **Remove Baseline** - baseline subtraction
- **Remove Artifact** - artifact removal
- **Artifact Window** - artifact window size
- **Show Original Traces** - show original traces
- **Auto Scale** - automatic scaling

The **Calculate** button builds the averaged signal graph.

![Mean trace by events](screenshots/mean_events.png)

## Mean Trace by Stimuli

Similarly to events, a mean trace by stimuli can be built. The **autoMeanStimulus** module is used through File Manager or similar settings in the Mean Events window when selecting stimuli as the source.

## Navigation by Events and Stimuli

Navigation by events and stimuli is available in Signal Viewer and Signal Analysis:

- Select **event** or **stimulus** mode in the view mode dropdown
- **Previous** and **Next** buttons move the displayed interval to the previous/next event or stimulus
- The time slider also works in event/stimulus navigation mode

## Event and Stimulus Visualization

Events and stimuli are displayed on the graph as vertical lines. Line color and style are configured through menu **View/Lines and styles**.

![Event and stimulus line styles](screenshots/lines_styles.png)

## Event Metadata

When automatically detecting events, metadata is saved:

- **Amplitude** - event amplitude
- **Channel** - event channel
- **Width** - peak width
- **Prominence** - peak prominence

Metadata is available through the events table and used in analysis.

