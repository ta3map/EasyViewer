#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт для генерации белых плейсхолдеров 100x100 пикселей
Использует base64 для создания минимального PNG без внешних библиотек
"""

import base64
import os

# Минимальный белый PNG 100x100 (1x1 пиксель, растягивается браузером)
# Это минимальный валидный PNG файл белого цвета
WHITE_PNG_1x1 = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
)

# Список всех плейсхолдеров
placeholders = [
    "placeholder_app_main.png",
    "placeholder_signal_viewer_main.png",
    "placeholder_load_zav_file.png",
    "placeholder_load_ev_file.png",
    "placeholder_time_slider.png",
    "placeholder_time_units.png",
    "placeholder_time_center_mode.png",
    "placeholder_time_window.png",
    "placeholder_navigation_buttons.png",
    "placeholder_additional_params.png",
    "placeholder_channel_table.png",
    "placeholder_events_table.png",
    "placeholder_manual_event_settings.png",
    "placeholder_auto_detection.png",
    "placeholder_edit_events.png",
    "placeholder_stimuli_table.png",
    "placeholder_edit_stimuli.png",
    "placeholder_filtering.png",
    "placeholder_average_subtraction.png",
    "placeholder_csd_settings.png",
    "placeholder_artifact_removal.png",
    "placeholder_mean_events.png",
    "placeholder_signal_analysis_main.png",
    "placeholder_analysis_channel.png",
    "placeholder_analysis_polarity.png",
    "placeholder_analysis_baseline.png",
    "placeholder_analysis_peak.png",
    "placeholder_analysis_time_window.png",
    "placeholder_analysis_visualization.png",
    "placeholder_analysis_current_results.png",
    "placeholder_analysis_smoothing.png",
    "placeholder_analysis_navigation_mode.png",
    "placeholder_analysis_results_table.png",
    "placeholder_analysis_average_table.png",
    "placeholder_analysis_hot_resave.png",
    "placeholder_analysis_graph_tools.png",
    "placeholder_file_manager_main.png",
    "placeholder_file_manager_database.png",
    "placeholder_file_manager_new_project.png",
    "placeholder_file_manager_projects_list.png",
    "placeholder_file_manager_new_group.png",
    "placeholder_file_manager_groups_list.png",
    "placeholder_file_manager_group_metadata.png",
    "placeholder_file_manager_add_file.png",
    "placeholder_file_manager_files_list.png",
    "placeholder_file_manager_file_metadata.png",
    "placeholder_file_manager_module_selection.png",
    "placeholder_file_manager_module_params.png",
    "placeholder_file_manager_run_module.png",
    "placeholder_file_manager_view_results.png",
    "placeholder_file_manager_import_excel.png",
    "placeholder_file_manager_search.png",
    "placeholder_file_manager_settings.png",
    "placeholder_module_cluster_test.png",
    "placeholder_module_mean_stimulus.png",
    "placeholder_module_detect_stimuli.png",
    "placeholder_module_slope_measurement.png",
    "placeholder_module_edit_params.png",
    "placeholder_module_queue.png",
    "placeholder_module_results.png",
    "placeholder_convert_nlx.png",
    "placeholder_convert_abf.png",
    "placeholder_convert_oep.png",
    "placeholder_import_lfp.png",
    "placeholder_filtering_channels.png",
    "placeholder_filtering_params.png",
    "placeholder_filtering_response.png",
    "placeholder_smoothing.png",
    "placeholder_channel_processing.png",
    "placeholder_zscore.png",
    "placeholder_spectral_density.png",
    "placeholder_event_crosscorrelation.png",
    "placeholder_channel_crosscorrelation.png",
    "placeholder_pca.png",
    "placeholder_data_operations.png",
    "placeholder_compare_average.png",
    "placeholder_boxplot_table.png",
    "placeholder_lines_styles.png",
    "placeholder_measurement_slope.png",
    "placeholder_measurement_peak.png",
    "placeholder_measurement_onset.png",
    "placeholder_measurement_baseline.png",
    "placeholder_zoom.png",
    "placeholder_pan.png",
    "placeholder_data_cursor.png",
    "placeholder_brush.png",
    "placeholder_save_figure.png",
]

# Создаем все плейсхолдеры
script_dir = os.path.dirname(os.path.abspath(__file__))
created = 0
skipped = 0

for placeholder in placeholders:
    filepath = os.path.join(script_dir, placeholder)
    if not os.path.exists(filepath):
        with open(filepath, 'wb') as f:
            f.write(WHITE_PNG_1x1)
        created += 1
        print(f"Created: {placeholder}")
    else:
        skipped += 1
        print(f"Skipped (already exists): {placeholder}")

print(f"\nTotal: {len(placeholders)} placeholders")
print(f"Created: {created}")
print(f"Skipped: {skipped}")
