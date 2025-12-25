# Automation Modules

Automation modules allow performing data analysis for multiple files without manual intervention.

## Available Modules

### autoClusterPermutationTest

Cluster permutation test for statistical analysis of time series.

**Visualization parameters:**
- **xLimits** - analysis time window in milliseconds [before stimulus, after stimulus]
- **removeBaseline** - whether to remove baseline mean value
- **removeArtifact** - whether to remove stimulus artifact
- **artifactWindow_ms** - artifact window duration in milliseconds
- **showBaselinePeriod** - whether to show baseline period on graph
- **showMeanSignal** - whether to show mean signal

**Test parameters:**
- **numPermutations** - number of permutations (recommended 1000-10000)
- **clusterThreshold** - significance level for t-statistic threshold (usually 0.05)
- **minClusterSize_ms** - minimum cluster size in milliseconds
- **startTrial** / **endTrial** - trial range for analysis (empty for all)
- **removeEdgeTrials** - whether to remove edge trials

**Output data:**
- Graph with t-statistics and significant clusters
- .meta file with analysis results

Detailed method description: [Cluster Permutation Test](cluster_permutation_test_eng.md)

![Cluster test result](images/placeholder_module_cluster_test.png)

### autoMeanStimulus

Signal averaging by stimuli with automatic peak detection.

**Visualization parameters:**
- **autoScale** - automatic scaling
- **xLimits** - time window in milliseconds
- **showOriginalTraces** - show original traces
- **removeBaseline** - remove baseline
- **removeArtifact** - remove artifact
- **artifactWindow_ms** - artifact window size

**Detection parameters:**
- **Polarity** - peak polarity (positive/negative)
- **MinPeakProminence** - minimum peak prominence
- **MinPeakDistance_s** - minimum distance between peaks
- **MaxPeakWidth_s** - maximum peak width
- **SmoothingKernel_s** - smoothing kernel size
- **UseOriginalData** - use original data for detection

**Output data:**
- Averaged signal graph with detected peaks
- Table with detection results
- Image file (PNG or FIG)

![Mean stimulus result](images/placeholder_module_mean_stimulus.png)

### autoDetectStimuli

Automatic detection of stimuli in the signal.

**Detection parameters:**
- **Polarity** - stimulus polarity (positive/negative)
- **MinPeakProminence** - minimum peak prominence
- **MinPeakDistance_s** - minimum distance between stimuli
- **MaxPeakWidth_s** - maximum stimulus width
- **SmoothingKernel_s** - smoothing kernel size
- **Channel** - channel number for detection

**Output data:**
- Timestamps of detected stimuli
- Saving stimuli to settings file

![Stimulus detection result](images/placeholder_module_detect_stimuli.png)

### autoSlopeMeasurement

Automatic slope measurement for all stimuli.

**Measurement parameters:**
- **Channel** - channel number
- **BaselineStart_s** - baseline range start (relative to stimulus)
- **BaselineEnd_s** - baseline range end
- **PeakStart_s** - peak range start
- **PeakEnd_s** - peak range end
- **SlopePercent** - percentage for slope calculation
- **PeakPolarity** - peak polarity (positive/negative)

**Time window parameters:**
- **TimeBack_s** - time before stimulus
- **TimeForward_s** - time after stimulus

**Processing parameters:**
- **SmoothingEnabled** - enable smoothing
- **SmoothingSpan** - smoothing kernel size
- **SmoothingMethod** - smoothing method (moving/median)
- **RemoveArtifact** - remove artifact
- **ArtifactWindow_ms** - artifact window size

**Output data:**
- Excel file with measurement results for all stimuli
- Measurement metadata

![Slope measurement result](images/placeholder_module_slope_measurement.png)

## Using Modules

### Parameter Configuration

1. Open File Manager
2. Select a module from the **Module** dropdown
3. Press the **Edit Module Params** button
4. Configure parameters in the opened window
5. Save parameters

![Module parameters configuration](images/placeholder_module_edit_params.png)

### Running Module

1. Select files in the File Manager list
2. Select a module
3. Press the **Launch Module** button
4. Wait for processing to complete

### Module Queue

Modules can be added to a queue for sequential execution:

1. Configure module parameters
2. Press the **Add to queue** button
3. Repeat for other modules
4. Press the **Launch Module** button to execute the entire queue

![Module queue](images/placeholder_module_queue.png)

### Viewing Results

Analysis results are saved to the File Manager database. To view:

1. Select a file in the list
2. Results are displayed in the **Results** table
3. Select a result and press **Open Result** to view

![Module results](images/placeholder_module_results.png)

## Parameter Format

Module parameters are stored in JSON format. Configuration files are located in the `modules/` folder:

- `autoClusterPermutationTest.json`
- `autoMeanStimulus.json`
- `autoDetectStimuli.json`
- `autoSlopeMeasurement.json`

## Analysis Results

Results are saved to the File Manager database in the `analysis_results` table:

- **module_name** - module name
- **module_display_name** - display name
- **module_description** - module description
- **analysis_timestamp** - analysis timestamp
- **report_path** - path to report file
- **parameters_json** - JSON with analysis parameters

Report files (graphs, tables) are saved in the folder with source data.

