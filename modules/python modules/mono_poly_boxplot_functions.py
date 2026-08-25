import pandas as pd
import numpy as np
from scipy import stats
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from typing import Dict, Any, List, Tuple


def load_excel_data(excel_path: str) -> pd.DataFrame:
    return pd.read_excel(excel_path)


def parse_group_filters(filters_str: str) -> List[List[Tuple[str, str, Any]]]:
    result = []
    normalized = filters_str.replace('\r\n', '\n').replace('\r', '\n')
    
    groups = []
    for line in normalized.split('\n'):
        line = line.strip()
        if not line:
            continue
        for part in line.split(';'):
            part = part.strip()
            if part:
                groups.append(part)
    
    letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    
    for group in groups:
        group_cleaned = ' '.join(group.split())
        
        if ':' in group_cleaned:
            first_part = group_cleaned.split(':')[0].strip()
            if first_part in letters:
                group_cleaned = group_cleaned.split(':', 1)[1].strip()
        
        conditions = []
        parts = [p.strip() for p in group_cleaned.split(',')]
        
        for part in parts:
            operators = ['>=', '<=', '!=', '>', '<', '=']
            operator = None
            operator_pos = -1
            
            for op in operators:
                pos = part.find(op)
                if pos > 0:
                    operator = op
                    operator_pos = pos
                    break
            
            if operator is None:
                if '=' in part:
                    key, value = part.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    operator = '='
                else:
                    continue
            else:
                key = part[:operator_pos].strip()
                value = part[operator_pos + len(operator):].strip()
            
            if value == '' or value.lower() in ['null', 'nan', 'none', 'empty']:
                parsed_value = None
            else:
                try:
                    if '.' in value:
                        parsed_value = float(value)
                    else:
                        parsed_value = int(value)
                except ValueError:
                    parsed_value = value
            
            conditions.append((key.strip(), operator, parsed_value))
        
        result.append(conditions)
    
    return result


def _parse_group_labels(labels_str: str) -> Dict[str, str]:
    result = {}
    if not labels_str or labels_str.strip() == '':
        return result
    
    normalized = labels_str.replace('\r\n', '\n').replace('\r', '\n')
    parts = []
    for line in normalized.split('\n'):
        line = line.strip()
        if not line:
            continue
        for part in line.split(','):
            part = part.strip()
            if part:
                parts.append(part)
    
    for part in parts:
        if ':' in part:
            key, value = part.split(':', 1)
            result[key.strip()] = value.strip()
    
    return result


def _parse_group_colors(colors_str: str) -> Dict[str, str]:
    result = {}
    if not colors_str or colors_str.strip() == '':
        return result
    
    normalized = colors_str.replace('\r\n', '\n').replace('\r', '\n')
    parts = []
    for line in normalized.split('\n'):
        line = line.strip()
        if not line:
            continue
        for part in line.split(','):
            part = part.strip()
            if part:
                parts.append(part)
    
    for part in parts:
        if ':' in part:
            key, value = part.split(':', 1)
            result[key.strip()] = value.strip()
    
    return result


def _diagnose_filtering(df: pd.DataFrame, group_conditions: List[List[Tuple[str, str, Any]]], custom_labels: Dict[str, str] = None) -> str:
    letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    diagnosis = []
    diagnosis.append(f"Всего строк в данных: {len(df)}")
    diagnosis.append(f"Колонки в данных: {', '.join(df.columns.tolist())}")
    diagnosis.append("")
    
    for idx, conditions in enumerate(group_conditions):
        default_label = letters[idx % len(letters)]
        group_label = custom_labels.get(default_label, default_label) if custom_labels else default_label
        diagnosis.append(f"Группа {group_label} (буква {default_label}):")
        
        mask = pd.Series([True] * len(df), index=df.index)
        initial_count = len(df)
        
        for key, operator, value in conditions:
            if key not in df.columns:
                diagnosis.append(f"  ❌ Колонка '{key}' не найдена в данных!")
                diagnosis.append(f"     Доступные колонки: {', '.join(df.columns.tolist())}")
                mask = pd.Series([False] * len(df), index=df.index)
                break
            
            col = df[key]
            before_count = mask.sum()
            
            if operator == '=':
                if value is None:
                    mask = mask & (col.isna() | (col == ''))
                else:
                    mask = mask & (col == value)
            elif operator == '>=':
                mask = mask & (col >= value)
            elif operator == '<=':
                mask = mask & (col <= value)
            elif operator == '>':
                mask = mask & (col > value)
            elif operator == '<':
                mask = mask & (col < value)
            elif operator == '!=':
                if value is None:
                    mask = mask & col.notna() & (col != '')
                else:
                    mask = mask & (col != value)
            
            after_count = mask.sum()
            unique_vals = col[mask].unique() if mask.sum() > 0 else []
            unique_vals_str = ', '.join([str(v) for v in unique_vals[:10]])
            if len(unique_vals) > 10:
                unique_vals_str += f", ... (всего {len(unique_vals)} уникальных)"
            
            diagnosis.append(f"  {key}{operator}{value}: {before_count} -> {after_count} строк")
            if after_count == 0:
                all_unique = col.unique()
                all_unique_str = ', '.join([str(v) for v in all_unique[:20]])
                if len(all_unique) > 20:
                    all_unique_str += f", ... (всего {len(all_unique)} уникальных)"
                diagnosis.append(f"     ⚠️ Все значения в колонке '{key}': {all_unique_str}")
        
        final_count = mask.sum()
        diagnosis.append(f"  Итого для группы {group_label}: {final_count} строк из {initial_count}")
        diagnosis.append("")
    
    return "\n".join(diagnosis)


def create_filtered_groups(df: pd.DataFrame, filters_str: str, custom_labels: Dict[str, str] = None) -> Tuple[pd.DataFrame, Dict[str, str], Dict[str, str]]:
    df = df.copy()
    group_conditions = parse_group_filters(filters_str)
    
    diagnosis = _diagnose_filtering(df, group_conditions, custom_labels)
    print("=" * 80)
    print("ДИАГНОСТИКА ФИЛЬТРАЦИИ ГРУПП:")
    print("=" * 80)
    print(diagnosis)
    print("=" * 80)
    
    df['group_label'] = None
    group_labels_map = {}
    label_to_letter = {}
    
    letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    
    for idx, conditions in enumerate(group_conditions):
        default_label = letters[idx % len(letters)]
        group_label = custom_labels.get(default_label, default_label) if custom_labels else default_label
        label_to_letter[group_label] = default_label
        mask = pd.Series([True] * len(df), index=df.index)
        
        for key, operator, value in conditions:
            if key not in df.columns:
                mask = pd.Series([False] * len(df), index=df.index)
                break
            
            col = df[key]
            
            if operator == '=':
                if value is None:
                    mask = mask & (col.isna() | (col == ''))
                else:
                    mask = mask & (col == value)
            elif operator == '>=':
                mask = mask & (col >= value)
            elif operator == '<=':
                mask = mask & (col <= value)
            elif operator == '>':
                mask = mask & (col > value)
            elif operator == '<':
                mask = mask & (col < value)
            elif operator == '!=':
                if value is None:
                    mask = mask & col.notna() & (col != '')
                else:
                    mask = mask & (col != value)
        
        df.loc[mask, 'group_label'] = group_label
        group_labels_map[group_label] = ', '.join([f"{key}{operator}{value}" for key, operator, value in conditions])
    
    result_df = df[df['group_label'].notna()]
    print(f"Итоговое количество строк после фильтрации: {len(result_df)}")
    if len(result_df) > 0:
        print(f"Созданные группы: {', '.join(sorted(result_df['group_label'].unique()))}")
        for label in sorted(result_df['group_label'].unique()):
            count = len(result_df[result_df['group_label'] == label])
            print(f"  {label}: {count} строк")
    else:
        print("⚠️ ВНИМАНИЕ: После фильтрации не осталось ни одной строки!")
    print("=" * 80)
    
    return result_df, group_labels_map, label_to_letter


def calculate_group_statistics(df: pd.DataFrame, parameters: List[str]) -> Dict[str, Any]:
    stats_dict = {}
    
    for param in parameters:
        param_stats = df.groupby(['group_label'])[param].agg([
            ('mean', 'mean'),
            ('std', 'std'),
            ('median', 'median'),
            ('q25', lambda x: x.quantile(0.25)),
            ('q75', lambda x: x.quantile(0.75)),
            ('count', 'count')
        ]).reset_index()
        
        stats_dict[param] = param_stats
    
    return stats_dict


def perform_statistical_tests(df: pd.DataFrame, parameters: List[str], label_to_letter: Dict[str, str] = None) -> Dict[str, Any]:
    results = {}
    
    for param in parameters:
        param_results = {}
        
        all_labels = df['group_label'].unique()
        if label_to_letter:
            group_labels = sorted(all_labels, key=lambda x: label_to_letter.get(x, x))
        else:
            group_labels = sorted(all_labels)
        
        for i in range(len(group_labels)):
            for j in range(i + 1, len(group_labels)):
                group1 = group_labels[i]
                group2 = group_labels[j]
                
                data1 = df[df['group_label'] == group1][param].dropna().values
                data2 = df[df['group_label'] == group2][param].dropna().values
                
                if len(data1) > 0 and len(data2) > 0:
                    stat, pvalue = stats.ttest_ind(data1, data2)
                    key = f"{group1}_vs_{group2}"
                    param_results[key] = {
                        'statistic': float(stat),
                        'pvalue': float(pvalue),
                        'n1': len(data1),
                        'n2': len(data2),
                        'group1': group1,
                        'group2': group2
                    }
        
        results[param] = param_results
    
    return results


def _p_to_stars(p: float) -> str:
    if not np.isfinite(p):
        return ""
    if p < 0.001:
        return "***"
    if p < 0.01:
        return "**"
    if p < 0.05:
        return "*"
    return "ns"


def _add_significance_branches(fig, group_labels: List[str], test_results: Dict[str, Any], 
                               y_max: float, y_min: float, y_base_offset: float, 
                               y_level_spacing: float, y_text_offset: float,
                               row: int, col: int, axis_idx: int, label_to_letter: Dict[str, str] = None,
                               show_all_pvalues: bool = True):
    significant_pairs = []
    for key, test_data in test_results.items():
        pvalue = test_data['pvalue']
        if show_all_pvalues or pvalue < 0.05:
            significant_pairs.append({
                'group1': test_data['group1'],
                'group2': test_data['group2'],
                'pvalue': pvalue,
                'stars': _p_to_stars(pvalue)
            })
    
    if not significant_pairs:
        return
    
    if label_to_letter:
        sorted_labels = sorted(group_labels, key=lambda x: label_to_letter.get(x, x))
    else:
        sorted_labels = sorted(group_labels)
    
    group_positions = {label: pos for pos, label in enumerate(sorted_labels)}
    
    levels = []
    for pair in significant_pairs:
        pos1 = group_positions[pair['group1']]
        pos2 = group_positions[pair['group2']]
        
        level = 0
        for existing_level in levels:
            if not (pos2 < existing_level['start'] or pos1 > existing_level['end']):
                level = max(level, existing_level['level'] + 1)
        
        levels.append({'start': pos1, 'end': pos2, 'level': level})
        pair['level'] = level
        pair['pos1'] = pos1
        pair['pos2'] = pos2
    
    xref_id = 'x' if axis_idx == 1 else f'x{axis_idx}'
    yref_id = 'y' if axis_idx == 1 else f'y{axis_idx}'
    
    y_range = y_max - y_min
    bracket_wall_height = y_range * 0.03
    
    for pair in significant_pairs:
        y_base = y_max + y_base_offset
        y_line = y_base + pair['level'] * y_level_spacing
        y_wall_bottom = y_line - bracket_wall_height
        y_text = y_line + y_text_offset
        
        fig.add_shape(
            type="line",
            x0=pair['pos1'], y0=y_line,
            x1=pair['pos2'], y1=y_line,
            line=dict(color="black", width=1.5),
            xref=xref_id,
            yref=yref_id,
            row=row, col=col
        )
        
        fig.add_shape(
            type="line",
            x0=pair['pos1'], y0=y_line,
            x1=pair['pos1'], y1=y_wall_bottom,
            line=dict(color="black", width=1.5),
            xref=xref_id,
            yref=yref_id,
            row=row, col=col
        )
        
        fig.add_shape(
            type="line",
            x0=pair['pos2'], y0=y_line,
            x1=pair['pos2'], y1=y_wall_bottom,
            line=dict(color="black", width=1.5),
            xref=xref_id,
            yref=yref_id,
            row=row, col=col
        )
        
        ptext = f"p={pair['pvalue']:.3f}" if pair['pvalue'] >= 0.001 else "p<0.001"
        annotation_text = f"{ptext} {pair['stars']}"
        
        fig.add_annotation(
            text=annotation_text,
            xref=xref_id,
            yref=yref_id,
            x=(pair['pos1'] + pair['pos2']) / 2,
            y=y_text,
            showarrow=False,
            font=dict(size=10, color="black"),
            bgcolor="rgba(255,255,255,0.9)",
            bordercolor="black",
            borderwidth=1,
            borderpad=2
        )


def create_boxplot_dashboard(df: pd.DataFrame, parameters: List[str], stats: Dict[str, Any], 
                            group_labels_map: Dict[str, str] = None, group_colors: Dict[str, str] = None,
                            label_to_letter: Dict[str, str] = None, title: str = None, 
                            show_all_pvalues: bool = True, y_axis_range: str = 'auto') -> go.Figure:
    n_params = len(parameters)
    rows = int(np.ceil(n_params / 2))
    cols = 2
    
    fig = make_subplots(
        rows=rows, 
        cols=cols,
        subplot_titles=parameters,
        vertical_spacing=0.2,
        horizontal_spacing=0.12
    )
    
    for idx, param in enumerate(parameters):
        row = (idx // cols) + 1
        col = (idx % cols) + 1
        
        all_labels = df['group_label'].unique()
        if label_to_letter:
            group_labels = sorted(all_labels, key=lambda x: label_to_letter.get(x, x))
        else:
            group_labels = sorted(all_labels)
        
        for pos, group_label in enumerate(group_labels):
            filtered_df = df[df['group_label'] == group_label]
            data = filtered_df[param].dropna()
            
            n_samples = len(data)
            median_value = data.median() if n_samples > 0 else 0
            
            box_kwargs = {
                'y': data,
                'x': [pos] * len(data),
                'name': group_label,
                'boxpoints': 'all',
                'jitter': 0.5,
                'pointpos': -1.8,
                'showlegend': (idx == 0),
                'text': [f"File: {row['filename']}<br>Value: {row[param]:.3f}" for idx, row in filtered_df.iterrows()] if 'filename' in filtered_df.columns else None
            }
            
            if group_colors and group_label in group_colors:
                box_kwargs['marker_color'] = group_colors[group_label]
            
            fig.add_trace(
                go.Box(**box_kwargs),
                row=row, col=col
            )
            
            # Добавляем аннотацию с количеством семплов в медиане
            if n_samples > 0:
                fig.add_annotation(
                    text=f"n={n_samples}",
                    xref='x' if (row - 1) * 2 + col == 1 else f'x{(row - 1) * 2 + col}',
                    yref='y' if (row - 1) * 2 + col == 1 else f'y{(row - 1) * 2 + col}',
                    x=pos,
                    y=median_value,
                    showarrow=False,
                    font=dict(size=9, color="black"),
                    bgcolor="rgba(255,255,255,0.8)",
                    bordercolor="black",
                    borderwidth=1,
                    borderpad=2,
                    row=row, col=col
                )
        
        fig.update_xaxes(
            tickmode='array',
            tickvals=list(range(len(group_labels))),
            ticktext=group_labels,
            tickangle=-45,
            row=row, col=col
        )
        
        y_data_all = df[param].dropna()
        
        # Определяем границы в зависимости от выбранного способа (нужны для скобок значимости)
        if y_axis_range == 'minmax':
            y_min = y_data_all.min()
            y_max = y_data_all.max()
        elif y_axis_range == 'percentile':
            y_min = y_data_all.quantile(0.05)
            y_max = y_data_all.quantile(0.95)
        else:  # auto
            y_min = y_data_all.min()
            y_max = y_data_all.max()
        
        y_range = y_max - y_min
        
        max_level = 0
        if param in stats:
            test_results = stats[param]
            significant_pairs = [t for t in test_results.values() if t['pvalue'] < 0.05]
            if significant_pairs:
                group_labels_sorted = sorted(df['group_label'].unique())
                group_positions = {label: pos for pos, label in enumerate(group_labels_sorted)}
                levels = []
                for pair_data in significant_pairs:
                    pos1 = group_positions[pair_data['group1']]
                    pos2 = group_positions[pair_data['group2']]
                    level = 0
                    for existing_level in levels:
                        if not (pos2 < existing_level['start'] or pos1 > existing_level['end']):
                            level = max(level, existing_level['level'] + 1)
                    levels.append({'start': pos1, 'end': pos2, 'level': level})
                    max_level = max(max_level, level)
        
        # Параметры для скобок значимости (нужны всегда)
        y_base_offset = y_range * 0.05
        y_level_spacing = y_range * 0.08
        y_text_offset = y_range * 0.015
        
        # Обновляем оси Y
        if y_axis_range == 'auto':
            # Не задаем range, позволяем plotly автоматически определить
            fig.update_yaxes(
                title_text=param,
                row=row, col=col
            )
        else:
            # Задаем range вручную с учетом скобок значимости
            y_range_top = y_max + y_base_offset + (max_level + 1) * y_level_spacing + y_text_offset
            
            # Добавляем небольшой отступ снизу
            y_range_bottom = y_min - y_range * 0.05 if y_min >= 0 else y_min * 1.05
            
            fig.update_yaxes(
                title_text=param,
                range=[y_range_bottom, y_range_top],
                row=row, col=col
            )
        
        if param in stats:
            test_results = stats[param]
            axis_index = (row - 1) * 2 + col
            _add_significance_branches(fig, group_labels, test_results, y_max, y_min, y_base_offset, y_level_spacing, y_text_offset, row, col, axis_index, label_to_letter, show_all_pvalues)
    
    title_text = title if title and title.strip() else "Сравнение параметров ответов по группам"
    
    fig.update_layout(
        title_text=title_text,
        height=rows * 500,
        showlegend=True,
        margin=dict(b=100, t=100)
    )
    
    return fig

