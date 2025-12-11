---
name: Fix boxplot filtering and statistics logic
overview: "Исправить логику: для каждого параметра применить его фильтр один раз, использовать отфильтрованные данные для отображения и статистики, вычислять статистику между параметрами на полотне (не между группами из фильтров)."
todos:
  - id: refactor-filtering
    content: "Переделать логику фильтрации: для каждого параметра применить фильтр один раз, сохранить отфильтрованные данные для отображения и статистики"
    status: pending
  - id: fix-statistics
    content: Вычислить статистику между отфильтрованными данными параметров (не между группами из фильтров)
    status: pending
    dependencies:
      - refactor-filtering
  - id: fix-brackets
    content: Исправить отображение скобок значимости между параметрами на полотне
    status: pending
    dependencies:
      - fix-statistics
---

# Исправление логики фильтрации и статистики

## Проблема

Сейчас фильтрация применяется дважды (для отображения и для статистики), что создает дублирование.

## Текущий dataflow (КАК СЕЙЧАС):

```mermaid
flowchart TD
    A[plotBoxplotCallback] -->|parameters| B[createBoxplotFigure]
    B -->|groupNumber| C[Группировка параметров по groupNumber]
    C -->|paramsInGroup| D[Цикл по параметрам]
    
    D -->|param1| E1[Применить фильтр param1]
    E1 -->|filteredTable1| F1[Собрать данные из групп фильтра]
    F1 -->|data1 с группами| G[allDataForGroup для отображения]
    
    D -->|param2| E2[Применить фильтр param2]
    E2 -->|filteredTable2| F2[Собрать данные из групп фильтра]
    F2 -->|data2 с группами| G
    
    G -->|allDataForGroup| H[boxplot отображение]
    
    H -->|После отображения| I[СНОВА цикл по параметрам]
    I -->|param1| J1[СНОВА применить фильтр param1]
    J1 -->|filteredTable1| K1[Собрать ВСЕ данные]
    K1 -->|allData1| L[paramDataMap]
    
    I -->|param2| J2[СНОВА применить фильтр param2]
    J2 -->|filteredTable2| K2[Собрать ВСЕ данные]
    K2 -->|allData2| L
    
    L -->|paramDataMap| M[Статистика между параметрами]
    M -->|testResults| N[statisticalTests]
    N -->|statisticalTests| O[Скобки значимости]
    
    style E1 fill:#ffcccc
    style E2 fill:#ffcccc
    style J1 fill:#ffcccc
    style J2 fill:#ffcccc
    style I fill:#ffcccc
```

**Проблемы:**

- Фильтры применяются дважды (красные блоки)
- Дублирование кода
- Путаница с группами из фильтров

## Новый dataflow (КАК БУДЕТ):

```mermaid
flowchart TD
    A[plotBoxplotCallback] -->|parameters| B[createBoxplotFigure]
    B -->|groupNumber| C[Группировка параметров по groupNumber]
    C -->|paramsInGroup| D[Цикл по параметрам]
    
    D -->|param1| E1{Есть фильтр?}
    E1 -->|Да| F1[Применить фильтр param1]
    F1 -->|filteredTable1| G1[Собрать данные из групп фильтра]
    G1 -->|data1 с группами| H1[allDataForGroup для отображения]
    G1 -->|allData1 объединенные| I1[paramDataMap для статистики]
    
    E1 -->|Нет| J1[Все данные param1]
    J1 -->|data1| H1
    J1 -->|allData1| I1
    
    D -->|param2| E2{Есть фильтр?}
    E2 -->|Да| F2[Применить фильтр param2]
    F2 -->|filteredTable2| G2[Собрать данные из групп фильтра]
    G2 -->|data2 с группами| H2[allDataForGroup для отображения]
    G2 -->|allData2 объединенные| I2[paramDataMap для статистики]
    
    E2 -->|Нет| J2[Все данные param2]
    J2 -->|data2| H2
    J2 -->|allData2| I2
    
    H1 --> K[allDataForGroup]
    H2 --> K
    K -->|allDataForGroup| L[boxplot отображение]
    
    I1 --> M[paramDataMap]
    I2 --> M
    M -->|paramDataMap| N[Статистика между параметрами]
    N -->|testResults| O[statisticalTests]
    O -->|statisticalTests| P[Скобки значимости]
    
    style F1 fill:#ccffcc
    style F2 fill:#ccffcc
    style M fill:#ccffcc
    style N fill:#ccffcc
```

**Преимущества:**

- Фильтры применяются один раз (зеленые блоки)
- Нет дублирования
- Четкое разделение: данные для отображения (с группами) и данные для статистики (объединенные)

## Изменения в коде

### В `createBoxplotFigure` (строки 1080-1320):

1. **Убрать дублирование фильтрации** (строки 1213-1289)
2. **В цикле по параметрам** (1080-1176):

   - Применить фильтр один раз
   - Собрать данные для отображения (с группами из фильтра)
   - Собрать все данные для статистики (объединенные)

3. **После цикла**:

   - Вычислить статистику между параметрами из `paramDataMap`
   - Сохранить в `statisticalTests`

4. **Отобразить скобки** используя `statisticalTests`

### Файлы для изменения

- `functions/boxpl