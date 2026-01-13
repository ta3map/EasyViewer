---
name: Cluster Permutation Test Module
overview: Создание модуля для анализа значимости ответа через кластерный пермутационный тест. Модуль извлекает данные по триалам (как в autoMeanStimulus), разделяет на baseline и post-stimulus периоды, выполняет кластерный пермутационный тест и визуализирует результаты.
todos:
  - id: create_module_file
    content: Создать основной файл модуля modules/autoClusterPermutationTest.m с базовой структурой (загрузка данных, вызов функций, сохранение результатов)
    status: completed
  - id: create_params_json
    content: Создать файл параметров modules/autoClusterPermutationTest.json с настройками визуализации, параметрами теста и периодами
    status: completed
  - id: create_extract_trial_data
    content: Создать функцию functions/extractTrialData.m для извлечения данных по триалам с разделением на baseline и post-stimulus периоды
    status: completed
  - id: create_cluster_test
    content: Создать функцию functions/clusterPermutationTest.m для выполнения кластерного пермутационного теста (t-статистика, кластеры, пермутации, p-значения)
    status: completed
    dependencies:
      - create_extract_trial_data
  - id: create_visualization
    content: Создать функцию functions/plotClusterPermutationResults.m для визуализации результатов (средние сигналы, t-статистика, кластеры, таблица)
    status: completed
    dependencies:
      - create_cluster_test
  - id: integrate_module
    content: Интегрировать все функции в модуль autoClusterPermutationTest.m и протестировать полный поток данных
    status: completed
    dependencies:
      - create_module_file
      - create_extract_trial_data
      - create_cluster_test
      - create_visualization
---

# Модуль кластерного пермутационного теста

## Цель

Создать модуль `autoClusterPermutationTest.m` для статистического анализа значимости ответа через кластерный пермутационный тест. Данные извлекаются по триалам вокруг стимулов (как в `autoMeanStimulus.m`), но анализируются через сравнение baseline vs post-stimulus периодов с пермутационной статистикой.

## Структура модуля

### 1. Основной файл модуля: `modules/autoClusterPermutationTest.m`

Модуль следует структуре `autoMeanStimulus.m`:

- Принимает `(filePath, fileId, params)`
- Использует `zav_calling` для загрузки метаданных
- Извлекает данные по триалам через модифицированную версию логики из `plotMeanEvents.m`
- Выполняет кластерный пермутационный тест
- Создает визуализацию результатов
- Сохраняет результаты в формате, аналогичном `autoMeanStimulus`

### 2. Файл параметров: `modules/autoClusterPermutationTest.json`

Параметры модуля:

- **visualization**: `autoScale`, `xLimits` (диапазон нарезки, например [-500, 500] мс), `showOriginalTraces`, `removeBaseline`, `removeArtifact`, `artifactWindow_ms`
- **test_parameters**: 
- `numPermutations` (количество пермутаций, по умолчанию 1000)
- `clusterThreshold` (порог значимости для t-статистики, по умолчанию 0.05)
- `minClusterSize_ms` (минимальный размер кластера в мс)
- **output**: `figureFormat` ('png' или 'fig')

**Примечание**: Разделение на baseline и post-stimulus происходит автоматически по знаку времени относительно стимула (0): `time <= 0` → baseline, `time > 0` → post-stimulus. Диапазон нарезки задается через `xLimits` (аналогично `autoMeanStimulus.json`).

### 3. Функция кластерного пермутационного теста: `functions/clusterPermutationTest.m`

Новая функция для выполнения теста:

- **Входные данные**: 
- `baselineData` - массив триалов baseline (trials × timepoints × channels)
- `postStimData` - массив триалов post-stimulus (trials × timepoints × channels)
- `params` - параметры теста
- **Алгоритм**:

1. Вычисление t-статистики для каждой временной точки (baseline vs post-stimulus)
2. Определение кластеров значимых точек (превышающих порог)
3. Вычисление суммы t-статистик для каждого кластера
4. Пермутация меток условий N раз
5. Для каждой пермутации: пересчет статистики и максимального размера кластера
6. Сравнение наблюдаемых кластеров с распределением пермутированных
7. Вычисление p-значений для каждого кластера

- **Выходные данные**: структура с кластерами, p-значениями, статистиками, распределением пермутированных t-статистик (для построения "облака")

### 4. Функция визуализации: `functions/plotClusterPermutationResults.m`

Визуализация результатов:

- Для каждого канала отдельный график через `tiledlayout`
- На каждом графике:
- Временной ряд t-статистики (основная линия)
- "Облако" пермутаций (затененная область, показывающая распределение t-статистик из пермутаций, например, перцентили 2.5 и 97.5)
- Выделение значимых кластеров (заливка или маркеры на временной оси)
- Горизонтальные линии порога значимости
- Таблица с результатами (размер кластеров, p-значения) - опционально

### 5. Функция извлечения данных по триалам: `functions/extractTrialData.m`

Извлечение данных по триалам (логика из `plotMeanEvents.m`, но без усреднения):

- Использует глобальную переменную `stims` как источник временных точек
- Применяет `removeStimArtifact` к `lfp` до нарезки (если параметр включен)
- Нарезает данные точно так же, как в `plotMeanEvents.m`:
- `eventIdx = round(stims(i) * Fs)`
- `windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1)`
- `windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N)`
- `eventDataRaw = lfp(windowStart:windowEnd, :)`
- Принимает `meanWindow` (вычисляется из `xLimits`), `lfp`, `Fs`, `time`, `N`, и другие параметры
- Создает временную ось для каждого триала относительно стимула (0)
- Возвращает массив данных по триалам (3D массив: `trials × timepoints × channels`)
- Поддерживает `removeBaseline` (вычитание медианы из каждого триала)
- Разделяет данные на baseline и post-stimulus периоды автоматически по знаку времени:
- `time <= 0` → baseline
- `time > 0` → post-stimulus

## Поток данных

```javascript
autoClusterPermutationTest.m
  ↓
zav_calling(filePath) → metadata
  ↓
extractTrialData() → baselineData, postStimData (по триалам)
  ↓
clusterPermutationTest() → testResults (кластеры, p-значения)
  ↓
plotClusterPermutationResults() → figure
  ↓
Сохранение результатов (figure + .meta файл)
```

## Детали реализации

### Извлечение данных

- Использовать глобальную переменную `stims` как источник временных точек стимулов
- Применить `removeStimArtifact` к массиву `lfp` до нарезки (если параметр `removeArtifact` включен):
- `win_r = round(artifactWindow_ms * (Fs/1000))`
- `lfp = removeStimArtifact(lfp, stims, time, win_r)`
- Нарезать данные по триалам точно так же, как в `plotMeanEvents.m` (строки 73-80):
- Для каждого стимула `i`: `eventIdx = round(stims(i) * Fs)`
- `windowStart = max(eventIdx - round(meanWindow * Fs / 2), 1)`
- `windowEnd = min(windowStart + round(meanWindow * Fs) - 1, N)`
- `eventDataRaw = lfp(windowStart:windowEnd, :)`
- Создать временную ось для триала: `timeAxis = (windowStart:windowEnd) / Fs - stims(i)` (относительно стимула)
- Разделить каждый `eventDataRaw` на baseline и post-stimulus периоды автоматически по знаку времени:
- `baselineIdx = timeAxis <= 0`
- `postStimIdx = timeAxis > 0`
- `baselineData = eventDataRaw(baselineIdx, :)`
- `postStimData = eventDataRaw(postStimIdx, :)`
- Сохранить данные в формате: `trials × timepoints × channels` (отдельно для baseline и post-stimulus)

### Кластерный пермутационный тест

- Для каждой временной точки: независимый t-test между baseline и post-stimulus (стандартный подход для двух условий)
- Порог значимости: `clusterThreshold` (например, p < 0.05 или t-статистика > порога)
- Кластеры: соседние значимые точки (превышающие порог)
- Статистика кластера: сумма абсолютных значений t-статистик внутри кластера
- Пермутация: случайное перемешивание меток baseline/post-stimulus между триалами
- P-значение: доля пермутаций с кластерами больше или равными наблюдаемым

### Оптимизация через векторизацию

**1. Вычисление t-статистик для всех временных точек одновременно:**

- Использовать матричные операции вместо циклов:
- `mean_baseline = mean(baselineData, 1)` - средние для всех временных точек сразу
- `mean_poststim = mean(postStimData, 1)`
- `std_baseline = std(baselineData, 0, 1)`, `std_poststim = std(postStimData, 0, 1)`
- Объединенное стандартное отклонение: `pooled_std = sqrt(((n1-1)*std_baseline.^2 + (n2-1)*std_poststim.^2) / (n1+n2-2))`
- t-статистика векторизованно: `t_stats = (mean_baseline - mean_poststim) ./ (pooled_std * sqrt(1/n1 + 1/n2))`
- Результат: массив `timepoints × channels` за одну операцию

**2. Пермутация данных:**

- Объединить все триалы: `allData = [baselineData; postStimData]`
- Перемешивать индексы: `perm_indices = randperm(n1 + n2)`, `perm_data = allData(perm_indices, :, :)`
- Разделить обратно: `perm_baseline = perm_data(1:n1, :, :)`, `perm_poststim = perm_data(n1+1:end, :, :)`

**3. Определение кластеров:**

- Логические операции для маски значимости: `significant_mask = abs(t_stats) > threshold`
- Использовать `bwlabel` или `bwconncomp` для поиска связных компонентов (кластеров) вместо циклов
- Для каждого канала: `[labeled, numClusters] = bwlabel(significant_mask(:, ch))`

**4. Вычисление статистик кластеров:**

- Использовать `accumarray` для суммирования по кластерам:
- `cluster_sums = accumarray(labeled(labeled>0), abs(t_stats(labeled>0, ch)))`
- `max_cluster_stat = max(cluster_sums)`

**5. Структура оптимизированного алгоритма:**

- Векторизованное вычисление наблюдаемых t-статистик (все точки и каналы сразу)
- Векторизованное определение кластеров через `bwlabel`
- Цикл по пермутациям (не векторизуется, но внутри все операции векторизованы)
- Сохранение распределения пермутированных t-статистик для построения "облака"

### Визуализация

- Использовать `tiledlayout` для организации графиков: один график на канал
- Для каждого канала:
- Временной ряд t-статистики (линия)
- "Облако" пермутаций: затененная область между перцентилями (например, 2.5% и 97.5%) из распределения пермутированных t-статистик для каждой временной точки
- Выделение значимых кластеров: заливка или маркеры на временной оси, показывающие интервалы значимых кластеров
- Горизонтальные линии порога значимости (положительный и отрицательный пороги)
- Подпись канала и информация о значимых кластерах
- Таблица с результатами (размер кластеров, p-значения) - опционально, может быть в отдельной плитке или в заголовке

## Файлы для создания/изменения

1. `modules/autoClusterPermutationTest.m` - основной модуль
2. `modules/autoClusterPermutationTest.json` - параметры модуля
3. `functions/clusterPermutationTest.m` - функция теста (новая)
4. `functions/plotClusterPermutationResults.m` - функция визуализации (новая)
5. `functions/extractTrialData.m` - функция извлечения данных по триалам (новая)

## Зависимости

- Использует существующие функции: `zav_calling`, `calculateAndPlotMeanEvents` (частично), `removeStimArtifact`
- Следует структуре модулей из `modules/autoMeanStimulus.m`