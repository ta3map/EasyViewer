# План векторизации (замена циклов на быстрые операции)

Пошаговый план оптимизаций без MEX. Каждый шаг — отдельный коммит/PR, после шага проверка человеком на типичных данных.

Статусы: ⏳ не начато · 🔄 в работе · ✅ готово

---

## Шаг 1. `smooth1.m` — скользящее среднее

**Статус:** ✅

**Файлы:**
- `functions/smooth1.m`

**Сейчас:** цикл `for i = 1:n` с `mean(x(startIdx:endIdx))` в `movingAverage`.

**Замена:**
- `'moving'` → `movmean(x, span, 'Endpoints', 'shrink')`
- `'median'` — уже через `medfilt1`, без изменений

**Затронет (косвенно):** `applyFilter.m`, `csdCalc.m`, `plotMeanEvents.m`, `calculateMeanEvents.m`, `removeStimArtifact.m` (method `'smooth'`).

**Проверка:** сравнить выход `smooth1` до/после на одном векторе; прогон mean events и фильтра в viewer.

---

## Шаг 2. `ZavFilter.m` — `filtfilt` по всей матрице

**Статус:** ✅

**Файлы:**
- `functions/ZavFilter.m`

**Сейчас:** двойной цикл `channel × sweep`, `filtfilt` на каждый 1D-срез.

**Замена:**
```matlab
[n, nCh, nSw] = size(s);
s2 = reshape(s, n, nCh * nSw);
f2 = filtfilt(b1, a1, s2);          % method 1/4
filteredS = reshape(f2, n, nCh, nSw);
```
Для method 2/3 — 2–3 вызова `filtfilt` на `s2` / промежуточной матрице.

**Затронет:** `detectMUAzav.m`, конвертация NLX.

**Проверка:** MUA-детекция на одном канале, сравнить число спайков и `ampl`.

---

## Шаг 3. `applyFilter.m` — фильтрация и сглаживание матрицей

**Статус:** ✅

**Файлы:**
- `functions/applyFilter.m`

**Сейчас:**
- цикл по каналам: отражение краёв + `filtfilt`
- цикл по каналам: `smooth1`

**Замена:**
- Отражение и `filtfilt` для всех столбцов одной матрицей (как в шаге 2).
- Сглаживание: `movmean(filteredData, span, 1)` или вызов обновлённого `smooth1` на матрице (если `movmean` внутри `smooth1` не принимает 2D — вызывать `movmean` напрямую).

**Затронет:** `updatePlot.m`, `calculateMeanEvents.m`, viewer.

**Проверка:** включить фильтр в viewer, сравнить форму сигнала на нескольких каналах.

---

## Шаг 4. `resample1.m` — `interp1` для всех каналов

**Статус:** ✅

**Файлы:**
- `functions/resample1.m`
- `functions/updatePlot.m` (убрать цикл `for ch`, если `resample1` примет матрицу)
- `functions/csdCalc.m` (цикл по строкам CSD, строки ~89–91)

**Сейчас:** `interp1` по одному столбцу; в `updatePlot` — цикл по каналам.

**Замена:** если `x` — матрица `N × C`, один вызов `interp1(t_original, double(x), t_resampled, 'linear', 'extrap')`.

**Проверка:** downsampling в viewer (`newFs < Fs`), CSD с `csd_smooth_coef > 0`.

---

## Шаг 5. `removeStimArtifact.m` — убрать цикл по столбцам

**Статус:** ✅

**Файлы:**
- `functions/removeStimArtifact.m`

**Сейчас:** цикл `for col = 1:size(data_in, 2)` внутри цикла по стимулам.

**Замена (по методам):**
- `'linear'` — интерполяция сразу для всех столбцов через `linspace` и broadcasting
- `'median'` — одно медианное значение на все каналы
- `'pchip'` / `'spline'` — `interp1`/`pchip` с матрицей значений (строки `y_all` — вектор или матрица)

Цикл по стимулам оставить; убрать только внутренний цикл по каналам.

**Затронет:** `updatePlot.m`, `extractTrialData.m`, `calculateMeanEvents.m`, GUI.

**Проверка:** стим-артефакт removal в viewer и mean events.

---

## Шаг 6. Mean events — вычитание среднего и сглаживание матрицей

**Статус:** ✅

**Файлы:**
- `functions/plotMeanEvents.m`
- `functions/calculateMeanEvents.m`

**Сейчас:**
- циклы `for chIdx` для `SubtractMean` и сглаживания
- вложенные циклы `eventIdx × chIdx` для `originalEventsData`

**Замена:**
- `meanData = meanData - mean(meanData, 1)`
- `meanData = movmean(meanData, kernel_samples, 1)` (или `smooth1` на матрице после шага 1)
- для `originalEventsData`: `cellfun(@(x) x - mean(x,1), ...)` и аналог для сглаживания; либо временно собрать 3D-массив

**Проверка:** mean events plot, auto event detection на среднем.

---

## Шаг 7. Спайки — вынести повторяющуюся работу из цикла по events

**Статус:** ✅

**Файлы:**
- `functions/plotMeanEvents.m`
- `functions/calculateMeanEvents.m`
- `functions/calculateAndPlotMeanEvents.m` (дублирующий блок спайков, ~строка 220)

**Сейчас:** на каждое событие × канал заново фильтруются `ampl` по порогу и строится `histcounts`.

**Замена:**
1. До цикла по events: один раз отфильтровать timestamps по порогу для каждого `ch_inx`.
2. В цикле по events: только `histcounts(spk(t0 <= spk & spk < t1), edges)`.

**Проверка:** mean events со включёнными spikes/MUA.

---

## Шаг 8. Маска артефакта стимула на спайках

**Статус:** ✅

**Файлы:**
- `functions/calculateMeanEvents.m`
- `functions/updatePlot.m` (блок MUA, ~строки 345–353 и 401–409)
- `functions/calculateAndPlotMeanEvents.m`

**Сейчас:** цикл `for i = 1:length(stim_inxs)` с постепенным удалением элементов из вектора.

**Замена:** один раз построить интервалы `[t_start, t_end)` для всех стимулов; одна булева маска:
```matlab
inArtifact = false(size(spk_sec));
for i = 1:numel(tLo)
    inArtifact = inArtifact | (spk_sec >= tLo(i) & spk_sec < tHi(i));
end
spk_sec = spk_sec(~inArtifact);
```
(или эквивалент без роста вектора в цикле)

**Проверка:** mean events с `remove_artifact` + spikes; MUA mask в viewer.

---

## Шаг 9. `extractTrialData.m` — прямое индексирование

**Статус:** ✅

**Файлы:**
- `functions/extractTrialData.m` (`extractTrialSkip`, `extractTrialWrap`)

**Сейчас:** цикл `for sample = 1:requiredSamples` с поэлементным копированием строки LFP.

**Замена:**
- `extractTrialSkip` (границы OK): `eventDataRaw = lfp(windowStart_abs:windowEnd_abs, :)`
- `extractTrialWrap`: `idx = mod(windowStart_abs + (0:requiredSamples-1)' - 1, N) + 1; eventDataRaw = lfp(idx, :)`

**Затронет:** `autoClusterPermutationTest.m`, модули с триалами.

**Проверка:** cluster permutation test, extract trials на записи со стимулами.

---

## Шаг 10. `updatePlot.m` — мелкие векторизации

**Статус:** ✅

**Файлы:**
- `functions/updatePlot.m`

**Изменения:**
- Baseline subtraction (строки ~142–149): `median` по строкам + индексация по `baseline_subtract_active`
- Offsets для CSD (строки ~175–177): `offsets = -(0:numChannels-1) * shiftCoeff`
- Ресемплинг — после шага 4 цикл по каналам не нужен

**Проверка:** интерактивный viewer — слайдер времени, baseline subtract, CSD.

---

## Шаг 11. `csdCalc.m` — сглаживание и ресемпл CSD-матрицы

**Статус:** ✅

**Файлы:**
- `functions/csdCalc.m`

**Сейчас:**
- цикл `resample1` по строкам CSD
- цикл `medfilt1` + `smooth1` по строкам

**Замена:**
- один `interp1` / обновлённый `resample1` на `csd_image'`
- `medfilt1(csd_image.', span).'` и `movmean(csd_image.', span, 1).'`

**Проверка:** CSD в viewer и mean events с `show_CSD`.

---

## Шаг 12. `CalcMinVar.m` — скользящий std

**Статус:** ✅

**Файлы:**
- `functions/CalcMinVar.m`

**Сейчас:** `while`-цикл с `std(dataFlt(t:(t+win-1)))`.

**Замена:** `movstd(dataFlt, win)` с шагом `win2` (через downsampling индексов или `buffer` + `std`).

**Затронет:** `detectMUAzav.m`.

**Проверка:** конвертация NLX с MUA.

---

## Шаг 13. `clusterPermutationTest.m` — матричный t-тест

**Статус:** ✅

**Файлы:**
- `functions/clusterPermutationTest.m`

**Сейчас:** тройной цикл `timepoint × channel × trial`; тот же блок в цикле пермутаций.

**Замена:**
```matlab
diffs = fullTrialData - reshape(baseline_means, numTrials, 1, numChannels);
% mean, std, n по dim=1 → t_observed (timepoints × channels)
```
Вынести в локальную функцию `pairedTTest3D(diffs)`; переиспользовать в пермутациях.

**Проверка:** модуль cluster permutation на тестовых триалах.

---

## Не входит в этот план (отдельно / MEX / не CPU)

| Область | Причина |
|---------|---------|
| `findpeaks1.m`, `detectPeaksInOriginalData.m` | Алгоритм + `findchangepts`; слабая выгода от простой векторизации |
| `detectMUAzav.m` (сегменты между порогами) | Разная длина сегментов |
| `multiplot.m` | Цикл `plot` — узкое место графика, не вычислений |
| GUI (`signalAnalysisGUI`, boxplot-модули) | Не горячий путь просмотра |

---

## Порядок работы

```
1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13
     ↑________________________|
     шаги 2–4 можно объединить в одну сессию (фильтр + resample)
```

После каждого шага: отметить статус в этом файле (⏳ → ✅).
