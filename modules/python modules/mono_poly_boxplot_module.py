from typing import Dict, Any, Optional, List, Tuple
import json
import plotly.graph_objects as go
from pathlib import Path
from ..base_analysis_module import BaseAnalysisModule
from ..functions.mono_poly_boxplot_functions import (
    load_excel_data,
    create_filtered_groups,
    calculate_group_statistics,
    perform_statistical_tests,
    create_boxplot_dashboard
)


class MonoPolyBoxplotModule(BaseAnalysisModule):
    
    def get_module_name(self) -> str:
        return "mono_poly_boxplot"
    
    def get_display_name(self) -> str:
        return "Анализ ответов int и pyr"
    
    def get_description(self) -> str:
        return "Визуализация моно- и полисинаптических ответов пирамидальных и интернейронов с группировкой по возрастам"
    
    def get_version(self) -> str:
        return "1.0.0"
    
    def get_parameters_schema(self) -> Dict[str, Any]:
        from collections import OrderedDict
        schema_path = Path(__file__).parent / "mono_poly_boxplot_schema.json"
        with open(schema_path, 'r', encoding='utf-8') as f:
            schema = json.load(f, object_pairs_hook=OrderedDict)
        return schema
    
    def analyze(self, udf_data: Dict[str, Any], parameters: Dict[str, Any], analysis_id: str = None, progress_store=None) -> Dict[str, Any]:
        from ..functions.mono_poly_boxplot_functions import _parse_group_labels
        
        excel_path = parameters['excel_path']
        group_filters = parameters['group_filters']
        show_statistics = parameters['show_statistics']
        show_all_pvalues = parameters['show_all_pvalues']
        y_axis_range = parameters['y_axis_range']
        group_labels_str = parameters['group_labels']
        group_colors_str = parameters['group_colors']
        title = parameters['title']
        analysis_columns_str = parameters['analysis_columns']
        
        if analysis_id:
            self.update_progress(analysis_id, 20, "Загрузка Excel файла...", progress_store)
        
        df = load_excel_data(excel_path)
        
        if analysis_id:
            self.update_progress(analysis_id, 60, "Применение фильтров и создание групп...", progress_store)
        
        custom_labels = _parse_group_labels(group_labels_str)
        df, group_labels_map, label_to_letter = create_filtered_groups(df, group_filters, custom_labels)
        
        normalized_columns = analysis_columns_str.replace('\r\n', '\n').replace('\r', '\n')
        parameters_list = [line.strip() for line in normalized_columns.split('\n') if line.strip()]
        
        if analysis_id:
            self.update_progress(analysis_id, 80, "Расчет статистики...", progress_store)
        
        group_stats = calculate_group_statistics(df, parameters_list)
        
        statistical_tests = {}
        if show_statistics:
            statistical_tests = perform_statistical_tests(df, parameters_list, label_to_letter)
        
        if analysis_id:
            self.update_progress(analysis_id, 100, "Анализ завершен", progress_store)
        
        from ..functions.mono_poly_boxplot_functions import _parse_group_colors
        
        group_colors_raw = _parse_group_colors(group_colors_str)
        group_colors = {}
        for label, letter in label_to_letter.items():
            if label in group_colors_raw:
                group_colors[label] = group_colors_raw[label]
            elif letter in group_colors_raw:
                group_colors[label] = group_colors_raw[letter]
        
        udf_data['analysis'] = udf_data.get('analysis', {})
        udf_data['analysis'][self.module_name] = {
            'dataframe': df,
            'group_stats': group_stats,
            'statistical_tests': statistical_tests,
            'excel_path': excel_path,
            'group_filters': group_filters,
            'group_labels_map': group_labels_map,
            'group_colors': group_colors,
            'label_to_letter': label_to_letter,
            'title': title,
            'parameters_list': parameters_list,
            'show_all_pvalues': show_all_pvalues,
            'y_axis_range': y_axis_range
        }
        
        return udf_data
    
    def visualize(self, udf_data: Dict[str, Any], 
                 channels: Optional[List[int]] = None,
                 time_range: Optional[Tuple[float, float]] = None,
                 **kwargs) -> go.Figure:
        analysis_results = self.get_analysis_results(udf_data)
        
        df = analysis_results.get('dataframe')
        statistical_tests = analysis_results.get('statistical_tests', {})
        group_labels_map = analysis_results.get('group_labels_map', {})
        group_colors = analysis_results.get('group_colors', {})
        label_to_letter = analysis_results.get('label_to_letter', {})
        title = analysis_results.get('title', None)
        show_all_pvalues = analysis_results.get('show_all_pvalues', True)
        y_axis_range = analysis_results.get('y_axis_range', 'auto')
        parameters_list = analysis_results.get('parameters_list', ['Slope', 'Peak Value (rel)', 'Onset Time (rel)', 'Peak-onset'])
        
        fig = create_boxplot_dashboard(df, parameters_list, statistical_tests, group_labels_map, group_colors, label_to_letter, title, show_all_pvalues, y_axis_range)
        
        return fig
    
    def handle_button_click(self, button_id: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        method_name = f"button_{button_id}"
        if hasattr(self, method_name):
            method = getattr(self, method_name)
            return method(parameters)
        
        return super().handle_button_click(button_id, parameters)
    
    def button_select_file(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        return {
            'success': True,
            'message': 'Открывается диалог выбора файла...',
            'data': {
                'action': 'call_api',
                'endpoint': '/api/analysis/modules/select_meta_file',
                'method': 'POST',
                'field_name': 'excel_path'
            },
            'file_type': 'excel'
        }

