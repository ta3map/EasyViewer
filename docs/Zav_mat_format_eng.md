# ZAV File Structure for MAT Files

## ZAV File Structure

ZAV files are MAT files with a specific variable structure used in Eviewer and Easy Viewer applications for analyzing electrophysiological data. Based on code analysis in `signalViewerGUI.m` and conversion functions, here is the required structure:

### Required Variables:

1. **`lfp`** - LFP (Local Field Potential) data matrix
   - Size: `[N, numChannels]` or `[N, numChannels, numSweeps]`
   - Where N is the number of time points, numChannels is the number of channels
   - If sweeps are present, the third dimension is the number of sweeps

2. **`hd`** - header structure with metadata
   - `fFileSignature` - file signature (e.g., "ABF2", "Neuralynx")
   - `nOperationMode` - operation mode
   - `lActualEpisodes` - number of episodes/sweeps
   - `nADCNumChannels` - number of channels
   - `recChNames` - array of channel names (cell array)
   - `recChUnits` - array of channel units (cell array)
   - `ch_si` - sampling intervals for each channel (in microseconds)
   - `dataPtsPerChan` - number of data points per channel
   - `dataPts` - total number of data points
   - `si` - sampling interval (in microseconds)
   - `fADCSampleInterval` - ADC sampling interval
   - `recTime` - recording time [start, end]

3. **`zavp`** - ZAV parameters structure
   - `file` - path to source file
   - `siS` - sampling interval in seconds
   - `dwnSmplFrq` - downsampled sampling frequency (in Hz)
   - `stimCh` - stimulation channel (may be empty)
   - `realStim` - structure with real stimuli
     - `r` - array of stimulation times (in time units)

4. **`spks`** - spikes structure
   - Array of structures for each channel
   - Each structure contains:
     - `tStamp` - spike timestamps (in milliseconds)
     - `ampl` - spike amplitudes
     - `shape` - spike shapes (may be empty)

5. **`lfpVar`** - LFP data variation
   - Vector of variations for each channel

6. **`chnlGrp`** - channel groups
   - May be empty array `[]`

### Additional Fields in `hd` (depending on data source):

- **For Neuralynx data:**
  - `adBitVolts` - bit-to-volt conversion coefficients
  - `dspDelay_mks` - DSP delays
  - `inverted` - channel inversion flags
  - `DSPLowCutFilterEnabled` - lowpass filter enable
  - `DspLowCutFrequency` - lowpass filter frequencies
  - `DSPHighCutFilterEnabled` - highpass filter enable
  - `DspHighCutFrequency` - highpass filter frequencies
  - `TTLs` - TTL events
  - `EventStrings` - event strings
  - `inTTL_timestamps` - TTL timestamps

- **For ABF data:**
  - `sweepStartInPts` - sweep start points
  - `protocolName` - protocol name
  - `nADCSamplingSeq` - ADC sampling sequence
  - `fTelegraphAdditGain` - additional gain coefficients
  - `fInstrumentScaleFactor` - instrument scale factors
  - `fSignalGain` - signal gain coefficients
  - `fADCProgrammableGain` - programmable ADC gain coefficients
  - `fInstrumentOffset` - instrument offsets
  - `fSignalOffset` - signal offsets

### Sweep Processing:

If data contains sweeps (third dimension of `lfp` > 1), the `sweepProcessData` function "unfolds" the data by combining all sweeps into one continuous time series, and also corrects stimulus and spike timestamps.

This structure ensures compatibility with Easy Viewer and allows correct display and analysis of electrophysiological data in various formats.

