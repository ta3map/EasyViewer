# Cluster Permutation Test Module

## Method Overview

The Cluster Permutation Test is a statistical method for analyzing time-series neurophysiological data that determines whether there are significant changes in the signal after a stimulus compared to the baseline period.

**Core idea:** The method compares each time point after the stimulus with the pre-stimulus period, identifies groups of adjacent significant points (clusters), and validates their statistical significance through multiple data permutations.

**Why it's needed:** Standard statistical tests face the multiple comparisons problem when analyzing time series — the more time points are tested, the higher the probability of false positives. The cluster permutation test addresses this by correcting statistical significance while accounting for multiple comparisons and the temporal structure of the data.

## How the Method Works

### 1. Data Preparation

The module extracts data around each stimulus (trial) within a specified time window. The window includes both the pre-stimulus period (baseline) and the post-stimulus period. For each trial, the mean baseline value is computed and used as a control point for comparison.

**Data processing:**
- Artifact removal (optional) — exclusion of a short period immediately after the stimulus
- Baseline removal (optional) — subtraction of the mean baseline value from each trial
- Cyclic padding — if a trial extends beyond recording boundaries, data is padded cyclically (beginning of recording is used for the end of the window and vice versa)

### 2. T-statistic Calculation

For each time point, a paired t-statistic is computed, showing how much the value at that point differs from the baseline within each trial.

**Formula:** For each trial, the difference between the value at a time point and the mean baseline of that trial is calculated. Then, across all trials, the t-statistic is computed as the ratio of the mean difference to the standard error.

**Effect direction:** The expected polarity of the effect (positive or negative) can be specified, which determines the direction of comparison. If a positive effect is expected, (post-stimulus - baseline) is computed; if negative, (baseline - post-stimulus).

### 3. Cluster Identification

Clusters are groups of adjacent time points where the t-statistic exceeds a specified significance threshold (e.g., |t| > 2.0, corresponding to p < 0.05 for a two-tailed test).

**Process:**
- All points where |t| > threshold are identified
- Adjacent significant points are grouped into clusters
- For each cluster, the sum of absolute t-statistics (or sum of squares) is computed — this is a measure of cluster "strength"
- The cluster onset time is recorded — the first time point of the cluster

### 4. Permutation Test

To validate the statistical significance of clusters, multiple permutations (shuffles) of the data are performed.

**Permutation process:**
- For each permutation, the signs of differences between time points and baseline are randomly flipped for each trial (multiplied by +1 or -1)
- This breaks the relationship between baseline and post-stimulus periods, creating a "null hypothesis"
- For each permutation, t-statistics are recomputed, clusters are identified, and the maximum cluster statistic is recorded

**Why sign flipping:** For a paired t-test (comparison within each trial), the correct null hypothesis is the absence of a systematic effect. Permuting the signs of differences preserves the data structure but randomly changes the direction of the effect, which is ideal for significance testing.

### 5. Significance Assessment

After all permutations, a distribution of maximum cluster statistics from permutations (null distribution) is formed.

**Significance criterion:**
- The observed cluster statistic is compared to this distribution
- If the observed statistic is greater than in 95% of permutations (or another specified percentage), the cluster is considered significant (p < 0.05)
- The p-value is computed as the proportion of permutations where the maximum statistic was greater than or equal to the observed one

**Multiple comparisons correction:** Since the maximum statistic from all clusters in each permutation is tested, the method automatically corrects for multiple comparisons. This means that even when testing thousands of time points, the false positive rate remains controlled.

## Module Parameters

### Visualization Parameters

- **xLimits** — Analysis time window in milliseconds [before stimulus, after stimulus]. For example, [-500, 500] means 500 ms before and 500 ms after the stimulus.
- **removeBaseline** — Whether to remove the mean baseline value from each trial before analysis.
- **removeArtifact** — Whether to remove the stimulus artifact (short period immediately after stimulus).
- **artifactWindow_ms** — Duration of the artifact window in milliseconds.
- **showBaselinePeriod** — Whether to show the baseline period on the results plot.

### Test Parameters

- **numPermutations** — Number of permutations for constructing the null distribution. At least 1000 is recommended; 5000-10000 for more accurate results.
- **clusterThreshold** — Significance level for determining the t-statistic threshold (usually 0.05, corresponding to a two-tailed test with |t| ≈ 2.0).
- **minClusterSize_ms** — Minimum cluster size in milliseconds. Clusters smaller than this are ignored (default 0 — all clusters are considered).
- **expectedPolarity** — Expected effect polarity: "positive" (signal increase) or "negative" (signal decrease).

## Interpreting Results

### Visualization

The plot shows:
- **Blue line** — Observed t-statistic for each time point
- **Gray area** — Confidence interval (percentiles) from permutations (usually 2.5% and 97.5%)
- **Green areas** — Significant clusters (p < 0.05)
- **Red markers** — Onset times of significant clusters with time labels in milliseconds
- **Black vertical line** — Stimulus moment (t = 0)

### Metadata

Results are saved to a file with the `.meta` extension and contain:
- **t_observed** — Matrix of observed t-statistics (time points × channels)
- **clusters** — Structure with cluster information for each channel (size, statistic, p-value, onset time)
- **perm_percentiles** — Percentiles of the permutation distribution
- **cluster_onsets** — One-dimensional array of onset times for all significant clusters (in seconds)

### Key Metrics

- **Onset time** — The moment when a significant effect begins after the stimulus. This is an important metric for understanding the temporal dynamics of the response.
- **Cluster size** — Duration of the significant effect. Large clusters indicate a sustained effect.
- **P-value** — Probability that the observed effect could have occurred by chance. P < 0.05 is considered significant.

## Advantages of the Method

1. **Multiple comparisons correction** — Automatically accounts for testing multiple time points
2. **Temporal structure consideration** — Clusters account for the fact that adjacent time points are correlated
3. **Non-parametric approach** — Does not require assumptions about data distribution
4. **Applicability to paired data** — Correctly handles comparison of baseline and post-stimulus within each trial
5. **Visual interpretation** — Results are easy to interpret visually

## Limitations

- The method requires a sufficient number of trials (at least 10-20 recommended)
- Permutation computation can be time-consuming with large numbers of time points and trials
- The method is sensitive to the choice of clustering threshold — too low a threshold may lead to false positives, too high — to missing real effects

## Applications

The module is used for:
- Determining whether there are significant signal changes after a stimulus
- Assessing the temporal dynamics of the effect (when it starts, how long it lasts)
- Comparing effects between different experimental conditions
- Validating results from other analysis methods


