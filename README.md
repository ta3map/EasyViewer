# Easy Viewer

[🇬🇧 English](README.md) | [🇷🇺 Русский](README_RU.md)

A program for viewing and analyzing electrophysiological signals.

## Table of Contents

- [Introduction](#introduction)
- [Getting Started](#getting-started)
- [Main Components](#main-components)
- [Detailed Documentation](#detailed-documentation)

## Introduction

Easy Viewer is designed for visualization and analysis of multi-channel electrophysiological signals (LFP). The program supports working with various data formats, provides tools for signal processing, event detection, parameter measurement, and analysis automation.

![Application main window](assets/splash_small.png)

## Getting Started

### Launching the Application

Launch the application by running the `app()` command in the MATLAB command window. The main window opens with two main modes of operation:

- **Signal Viewer** - signal viewing mode
- **Signal Analysis** - analysis and parameter measurement mode

![Application main window](docs/user_docs/screenshots/app_main.png)

### Selecting Operation Mode

Press the **Signal Viewer** button to open the signal viewing window or **Signal Analysis** to open the analysis window. Both modes can work independently, but when one window opens, the other automatically closes.

The **⚙** button opens global application settings.

## Main Components

### Signal Viewer

The signal viewing window is designed for visualization of multi-channel LFP signals, management of events and stimuli, signal processing, and basic analysis.

Main features:
- Loading files in ZAV (.mat) and EV (.ev) formats
- Viewing multi-channel signals with display configuration
- Event management (manual addition, automatic detection)
- Stimulus management
- Signal processing (filtering, mean subtraction, CSD)
- Analysis tools (Z-score, spectral density, PCA, correlation)

Detailed description: [Signal Viewer](docs/user_docs/signal_viewer/signal_viewer_eng.html)

### Signal Analysis

The analysis window is designed for measuring signal parameters relative to stimuli or events.

Main features:
- Parameter measurement (slope, peak, onset, baseline)
- Working with measurement table
- Signal smoothing
- Saving results to Excel
- Hot Resave for automatic re-saving
- Viewing mean trace by measurements

Detailed description: [Signal Analysis](docs/user_docs/signal_analysis/signal_analysis_eng.html)

## Detailed Documentation

### Main Components

- [Signal Viewer](docs/user_docs/signal_viewer/signal_viewer_eng.html) - signal viewing and event management
- [Signal Analysis](docs/user_docs/signal_analysis/signal_analysis_eng.html) - signal parameter measurement

### Processing and Analysis

- [Signal Processing](docs/user_docs/signal_viewer/signal_processing_eng.html) - filtering, CSD, mean subtraction
- [Analysis Tools](docs/user_docs/signal_viewer/analysis_tools_eng.html) - Z-score, spectral density, PCA, correlation
- [Events and Stimuli](docs/user_docs/signal_viewer/events_and_stimuli_eng.html) - event and stimulus management
- [Parameter Measurements](docs/user_docs/signal_analysis/measurements_eng.html) - slope, peak, onset, baseline
- [Visualization](docs/user_docs/signal_viewer/visualization_eng.html) - display and graph settings
