---
name: IOS mode iosPlayerGUI
overview: Добавление в iosPlayerGUI режима IOS (относительное изображение по формуле (frame-baseframe)/baseframe) с чекбоксом включения, заданием диапазона baseframe, кнопкой Set baseframe и опцией вычитания медианы; все элементы IOS видны только при включённом режиме.
todos: []
isProject: false
---

# Режим IOS в iosPlayerGUI

## Контекст

- **[iosPlayerGUI.m](c:\Users\AzaRGajnutdinov\Documents\EasyViewer\functions\GUIfunctions\iosPlayerGUI.m)** — плеер .ios: слайдер, навигация, один кадр через `readIOS2(..., 'startframe', k, 'endframe', k, 'Format', 'Lin')`, контраст.
- **readIOS2** поддерживает чтение диапазона кадров: `startframe`, `endframe`, возвращает `[data, t, ntrig]`, `data` — [H, W, N].
- **meta**: `totalFrames`, `t0`, `dt` — для перевода время ↔ номер кадра: `k = round((sec - meta.t0) / meta.dt) + 1`; 20 сек в кадрах: `n20 = round(20 / meta.dt)` (при `dt > 0`).

## Логика IOS

- **IOS_frame** = (frame - baseframe) / baseframe (в долях; при необходимости — в процентах для отображения).
- **baseframe** — средний кадр по диапазону [baseframeStart, baseframeEnd]: загрузка диапазона через readIOS2, затем `mean(data, 3)`.
- **Вычитание медианы** (опция): для каждого кадра и для baseframe использовать изображение минус медиана по всему кадру: `frame_adj = frame - median(frame(:))`, затем та же формула IOS от скорректированных кадров.

Обработка нулей в baseframe: при делении избегать деления на 0 (например, заменить нули в знаменателе на NaN и не отображать, или малая константа — по вкусу, в плане оставить явную обработку).

## Состояние (state)

Добавить в `state`:

- `iosMode` — логический (значение чекбокса «IOS»).
- `baseframeStart`, `baseframeEnd` — номера кадров (индексы 1..totalFrames).
- `baseframeData` — кэш: средний кадр [H,W] (double или single) или [] при сбросе/смене файла/диапазона.
- `subtractMedian` — логический (значение чекбокса вычитания медианы).

При открытии файла (`openFile`) сбрасывать: `baseframeData = []`, при необходимости задавать базовый диапазон по умолчанию (например, первые 20 сек: кадры 1..min(N, 1+round(20/dt))).

## UI

- **Строка под контрастом** (например, высота/позиция 0.22 или сдвиг контраста вниз):
  - Чекбокс **«IOS»** — главный переключатель режима IOS.
  - Рядом (видимы только при `iosMode == true`):
    - Два поля ввода: **Baseframe from**, **Baseframe to** (номера кадров или время — по желанию единый формат; минимально — номера кадров).
    - Кнопка **«Set baseframe»**: взять текущий кадр как начальный, конечный = начальный + 20 сек в кадрах (`baseframeEnd = baseframeStart + round(20/meta.dt)`), обновить поля и сбросить `baseframeData`.
    - Чекбокс **«Subtract median»** (вычитание медианы по всему изображению).
- Видимость: у всех элементов, кроме чекбокса «IOS», свойство `Visible` = 'off' по умолчанию; при включении «IOS» — 'on', при выключении — 'off' (в callback чекбокса «IOS»).

Имена хендлов, например: `hIosCheck`, `hBaseStartEdit`, `hBaseEndEdit`, `hSetBaseBtn`, `hSubtractMedianCheck`; сохранить в `state.h` и использовать в callback’ах и в `showFrame` для видимости.

## Вычисление baseframe

- Отдельная функция (например, `computeBaseframe(fig)`) или блок в `showFrame`:
  - Читать `[data, ~, ~] = readIOS2(state.iosPath, 'startframe', baseframeStart, 'endframe', baseframeEnd, 'Format', 'Lin')`.
  - Если опция «Subtract median»: для каждого кадра `data(:,:,i) = data(:,:,i) - median(data(:,:,i), 'all')`, затем `baseframe = mean(data, 3)`; иначе просто `baseframe = mean(data, 3)` (в double).
  - Сохранить в `state.baseframeData`, обновить `fig.UserData = state`.
- Вызывать при первом отображении в режиме IOS, если `isempty(state.baseframeData)` или диапазон изменился (по сравнению с тем, по которому кэш считался — можно хранить в state `baseframeRangeUsed = [start, end]` и сравнивать).

## Отображение в showFrame

- Если файл не открыт / meta пустой — без изменений.
- Загрузить текущий кадр `k` как сейчас.
- Если **IOS выключен**: отображать `frame` как сейчас (включая контраст по `state.clim`).
- Если **IOS включён**:
  - При необходимости вызвать вычисление baseframe (см. выше).
  - Применить вычитание медианы к текущему кадру и к baseframe, если опция включена:  
  `frame_adj = double(frame) - median(double(frame(:)));`  
  `base_adj = state.baseframeData` (уже посчитан с учётом медианы при кэшировании) или отдельно вычесть медиану из baseframe при включённой опции — единообразно: и baseframe, и текущий кадр в одной и той же схеме (оба либо с вычитанием медианы, либо без).
  - Вычислить IOS: `iosFrame = (frame_adj - base_adj) ./ base_adj`; обработать нули в знаменателе (например, `base_adj(base_adj == 0) = NaN` перед делением).
  - Отрисовать `iosFrame` в `state.him.CData`, подстроить `ax.CLim` под диапазон IOS (например, симметрично относительно 0 или по минимуму/максимуму без выбросов). Отдельно хранить/не трогать `state.clim` для обычного режима.

При переключении «IOS» вкл/выкл обновлять видимость блока и перерисовывать кадр (вызвать `showFrame` с текущим k).

## Callback’ы

- **IOS чекбокс**: обновить `state.iosMode`, включить/выключить видимость `hBaseStartEdit`, `hBaseEndEdit`, `hSetBaseBtn`, `hSubtractMedianCheck`; вызвать `showFrame(fig, ax, currentK)`.
- **Set baseframe**: взять `currentK = round(state.h.slider.Value)`, `baseframeStart = currentK`, `baseframeEnd = min(state.meta.totalFrames, currentK + round(20/state.meta.dt))` (при `dt <= 0` — фиксированный шаг, например +20 кадров); записать в state, обновить строки в полях «from»/«to», сбросить `baseframeData` (и при необходимости `baseframeRangeUsed`); при включённом IOS перерисовать кадр.
- **Baseframe from/to**: при изменении (Callback) парсить число кадра, класть в `state.baseframeStart`/`baseframeEnd`, сбросить `baseframeData`; при включённом IOS — перерисовать.
- **Subtract median**: обновить `state.subtractMedian`, сбросить `baseframeData` (т.к. baseframe пересчитывается с другой схемой), при включённом IOS вызвать `showFrame`.

## Инициализация при открытии файла

В `openFile`: задать `state.baseframeData = []`, при желании задать диапазон по умолчанию (например, 1 и 1+round(20/meta.dt)) и заполнить поля «from»/«to»; не включать автоматически режим IOS.

## Порядок работ

1. Добавить переменные состояния и хендлы IOS-элементов, разместить их на фигуре, видимость только чекбокса «IOS».
2. Реализовать вычисление baseframe (с опцией медианы) и кэширование в state.
3. В `showFrame` добавить ветку для режима IOS: подстановка baseframe, формула IOS, обновление CData и CLim.
4. Подключить callback’и (IOS, Set baseframe, from/to, Subtract median) и управление видимостью.
5. В `openFile` сбрасывать кэш baseframe и при необходимости инициализировать диапазон по умолчанию.

После этого режим IOS включается чекбоксом, baseframe задаётся диапазоном и кнопкой «Set baseframe», опция вычитания медианы применяется единообразно к кадру и baseframe, все дополнительные элементы скрыты при выключенном IOS.