# Easy Viewer
Программа для просмотра и анализа электрофизиологических сигналов

- [Начало работы](#начало-работы)
	- [Открытие файла ZAV](#открытие-файла-zav)
	- [Открытие файла EV](#открытие-файла-ev)
	- [Просмотр сигнала](#просмотр-сигнала)
- [Управление событиями](#управление-событиями)
	- [Добавление событий](#добавление-событий)
		- [Настройки ручного добавления событий](#настройки-ручного-добавления-событий)
	- [Автоматическое обнаружение событий](#автоматическое-обнаружение-событий)
	- [Средний трейс по событиям](#средний-трейс-по-событиям)
	- [Сохранение событий](#сохранение-событий)
	- [Удаление событий](#удаление-событий)
- [Обработка сигналов](#обработка-сигналов)
	- [Фильтрация](#фильтрация)
	- [Вычитание среднего](#вычитание-среднего)
	- [Отображение CSD](#отображение-csd)
- [Дополнительные возможности](#дополнительные-возможности)
	- [Конвертация в ZAV формат](#конвертация-в-zav-формат)
	- [Файловый менеджер](#файловый-менеджер)
	- [Настройки каналов](#настройки-каналов)
	- [Скрытие боковой панели](#скрытие-боковой-панели)

## Основное окно просмотра сигналов
Основное окно отображает многоканальные LFP сигналы. Пользователи могут наблюдать за активностью сигналов в разных каналах, что позволяет проводить визуальный анализ.

![Основное окно просмотра](https://github.com/ta3map/EasyViewer/blob/main/images//MainWindow.PNG)

## Начало работы

### Открытие файла ZAV
Для начала просмотра нужно нажать кнопку **Load .mat File (ZAV Format)** или выбрать **File/open ZAV (.mat) file**. Затем в появившимся окне выбора найти тот mat-файл что вас интересует.
Если файл до этого никем не открывался, то по-умолчанию будет отображен сигнал на всех каналах. При желании отображение можно поменять (см. пункт **Настройки каналов**)

См также: [Файловый менеджер](#файловый-менеджер), [Конвертация в ZAV формат](#конвертация-в-zav-формат), [Настройки каналов](#настройки-каналов)

### Открытие файла EV
В случае если для записанного эксперимента были обнаружены события и они были сохранены в файл .ev формата (см. [Сохранение событий](#save-events)), можно начать работу с отрытия ev-файла. Для этого надо нажать кнопку **Load Events** или выбрать **File/open event (.ev) file**.
Откроется окно для выбора ev-файлов. После выбора будут загружены LFP для соответствующих событий и сами события (см. [Управление событиями](#events-panel)).

### Просмотр сигнала
Панель управления временем позволяет выбирать интересующий временной диапазон для детального просмотра, а также быстро перемещаться между различными сегментами данных.

В меню имеется слайдер для перемотки времени, а также есть кнопки для пролистывания. 

Меню развертки времени содержит пункты **s**, **ms**, **min**, что соответствует секундам, милисекундам и минутам времени. Единицы отображаемые на оси времени всегда таким образом, устанавливаются соответственно выбору. 

![Пролистывание](https://github.com/ta3map/EasyViewer/blob/main/images/time1.PNG)

Окна времени до и после текущей временной точки устанавливают диапазон данного участка сигнала. 

![Диапазон отображения](https://github.com/ta3map/EasyViewer/blob/main/images/time2.PNG)

- `Fs` - частота дискретизации отображаемого сигнала;

- `Ch.Shift` - величина зазора между каналами в единицах соответствующих LFP сигналу;

- `CSD` - выбор отображения CSD;

- `MUA` - выбор отображения MUA;

- `MUA coef` - устанавливает порог отображения MUA, в условных единицах.

![Дополнительные Функции](https://github.com/ta3map/EasyViewer/blob/main/images/time3.PNG)

## Управление событиями
Инструменты для добавления, удаления и автоматического обнаружения событий на LFP сигнале, а также для сохранения и загрузки этих событий.

![Меню событий](https://github.com/ta3map/EasyViewer/blob/main/images/EventMenu.PNG)

### Добавление событий

Для точного маркирования и анализа значимых событий в электрофизиологических данных, программа предлагает функционал ручного добавления событий. Это можно сделать через кнопку **Add Event** или используя сочетание клавиш **Ctrl** и клик мыши в интересующем участке графика.

#### Настройки ручного добавления событий

![Настройки ручного добавления событий](https://github.com/ta3map/EasyViewer/blob/main/images/manualevent.PNG)

Ручное добавление событий позволяет пользователям с высокой точностью определять точки интереса, используя следующие параметры:

- **Режим Детекции (`Detection Mode`)**: Выберите `manual` для прямого добавления событий в указанный момент времени или `locked` для коррекции положения события относительно локального экстремума в заданном временном окне.

- **Номер Канала (`Channel Number`)**: Укажите канал, в котором необходимо добавить событие. В примере выбран `Ch 35`.

- **Полярность (`Polarity`)**: Выбор полярности определяет, будет ли система искать максимум или минимум в сигнале канала в зависимости от того, установлено значение `positive` или `negative`.

- **Временное Окно (`Time Window`)**: Задайте временное окно в миллисекундах, в пределах которого программа будет искать локальный экстремум при выбранном режиме `locked`.

После настройки параметров нажмите `Save` для их применения. В режиме `manual` метка будет добавлена непосредственно в выбранную точку, в то время как в режиме `locked` программа сначала определит наиболее значимую точку (максимум или минимум) в выбранном диапазоне, прежде чем разместить метку события.

#### Автоматическое обнаружение событий

Этот инструмент позволяет пользователям автоматизировать процесс обнаружения значимых событий, таких как пики или спады в электрофизиологических сигналах. Доступ к этому функционалу можно получить через кнопку `Auto Event Detection` в главном окне программы или через меню `Options/Auto Event Detection`.

![Автоматическое обнаружение событий](https://github.com/ta3map/EasyViewer/blob/main/images/autodetector.PNG)

##### Основные параметры детектора событий:

- **Тип Детекции (`Detection Type`)**: Вы можете выбрать тип детекции событий в зависимости от вашего анализа. Для анализа отдельных каналов используются параметры 'one channel positive' и 'one channel negative', а для сравнения активности между двумя каналами - 'two channels difference'.

- **Минимальная Амплитуда Пика (`Minimal Peak Amplitude`)**: Задает минимальный порог амплитуды для обнаружения пиков. Только события с амплитудой выше этого значения будут обнаружены.

- **Положительный Канал (`Positive Channel`)** и **Отрицательный Канал (`Negative Channel`)**: Выбор каналов для сравнения, если выбран режим 'two channels difference'. Это позволяет обнаруживать события, основанные на разнице активности между двумя каналами.

- **Минимальное Время Между Пиками (`Minimal Time Between Peaks`)**: Устанавливает минимальное время между обнаруженными пиками для исключения ложных срабатываний, связанных с близко расположенными событиями.

- **Коэффициент Сглаживания (`Smooth Coefficient`)**: Параметр для сглаживания сигнала перед обнаружением пиков, что помогает уменьшить влияние шума.

- **Режим Обнаружения (`Detection Mode`)**: Позволяет выбрать, будут ли обнаруживаться пики/спады (peaks) или же онсеты (onsets) сигнала.

После настройки параметров нажатие кнопки `Check Detection` позволяет просмотреть потенциальные события на графике сигнала, что дает возможность визуально подтвердить правильность настроек перед применением.

Кнопка `Apply` используется для запуска процесса обнаружения событий с выбранными настройками, после чего события будут добавлены в таблицу событий программы для дальнейшего анализа.


#### Средний трейс по событиям
- Кнопка `Mean Events` позволяет построить трейс состоящий из LFP сигнала, усредненного вокруг события.

#### Сохранение событий
- Кнопка `Save Events` позволяет сохранить весь текущий список событий. Это может быть полезно для документирования и последующего анализа значимых моментов в данных.
- При сохранении пользователь может указать имя файла и выбрать путь сохранения.

### Удаление событий

#### Удаление отдельно взятого события
- Выбрав событие из списка, можно использовать кнопку `Delete Event` для удаления конкретного события.
- Это позволяет очистить список от ошибочно добавленных или неактуальных событий, обеспечивая точность аналитических данных.

#### Очистка таблицы событий
- Кнопка `Clear Table` полностью очищает таблицу событий.
- Это может быть использовано для начала нового сеанса наблюдения без старых данных, что облегчает организацию и управление данными событий.

### Работа со списком
- Список событий отображает временные метки (`Time`) и комментарии (`Comment`), которые могут быть добавлены пользователем для каждого события, облегчая тем самым идентификацию и интерпретацию данных.
- Кнопки `Add Event`, `Delete Event` и `Clear Table` находятся под таблицей и обеспечивают легкое управление записями.


## Обработка сигналов

### Фильтрация

Для отрытия настроек фильтрации выберите **Options/Filtering**

![Фильтрация](https://github.com/ta3map/EasyViewer/blob/main/images/filtration_bandpass.PNG)

#### Выбор каналов
Слева находится панель, где пользователь может активировать или деактивировать фильтрацию для каждого канала (Ch 1 - Ch ...). Флажки позволяют легко управлять, какие каналы будут фильтроваться.

#### Параметры фильтра
Справа отображаются параметры фильтрации:
- Тип фильтра (`bandpass` на скриншоте) можно выбрать из выпадающего списка, который может включать, например, полосовой (`bandpass`), низкочастотный (`lowpass`) и высокочастотный (`hightpass`) фильтры.
- Частотные пороги фильтра задаются в полях ввода для нижней (`100 Hz`) и верхней (`200 Hz`) границ.
- Порядок фильтра (`4` на скриншоте) определяет крутизну склона фильтра.

#### Управление фильтрацией
- Кнопки `Select ALL` и `Deselect ALL` позволяют быстро выбрать все каналы или снять выбор со всех каналов соответственно.
- Кнопка `Check Filtration` позволяет предпросмотреть эффект фильтрации на частотной характеристике сигнала.
- Кнопки `Apply` и `Cancel` применяют настройки фильтрации к выбранным каналам или отменяют изменения.

#### График частотного отклика
В нижней части окна расположен график, отображающий частотный отклик фильтра (`Frequency Response`). Этот график помогает визуализировать эффекты, которые фильтр оказывает на сигнал, демонстрируя усиление или подавление в различных частотных диапазонах.


### Вычитание среднего

Для отрытия настроек вычитания среднего выберите **Options/Average subtraction**

![Вычитание среднего](https://github.com/ta3map/EasyViewer/blob/main/images/average_subtr.PNG)

#### Выбор каналов для обработки
- В левой части окна располагается список доступных каналов (Ch 25 - Ch 40), для каждого из которых можно включить или выключить применение функции вычитания среднего.
- Флажки (`Enabled`) позволяют выбирать индивидуальные каналы, для которых будет применяться данная обработка.

#### Управление выбором каналов
- С помощью кнопок `Select ALL` и `Deselect ALL` пользователь может быстро выбрать все каналы или отменить выбор со всех каналов соответственно для применения функции.

#### Применение настроек
- После того как необходимые каналы выбраны, нажатие на кнопку `Apply` применяет функцию вычитания среднего значения к выбранным каналам.
- Вычитание среднего значения помогает устранить общий для всех каналов фоновый шум, повышая точность анализа сигналов.

### Отображение CSD
Для отрытия настроек отображения CSD выберите **Options/CSD Displaying**

![Отображение CSD](https://github.com/ta3map/EasyViewer/blob/main/images/CSD_settings.PNG)

Функция CSD используется для визуализации пространственного распределения источников и стоков тока на основе записанных LFP данных, что позволяет выявить активные области мозга.

#### Выбор каналов
- Панель слева содержит список каналов (Ch 1 - Ch ...) с чекбоксами, которые позволяют включать или выключать отображение CSD для каждого отдельного канала.
- Пользователи могут настроить, для каких каналов будет рассчитываться и отображаться CSD, включая или исключая их из анализа.

#### Быстрое управление каналами
- Кнопки `Select ALL` и `Deselect ALL` обеспечивают быстрый выбор всех каналов для включения в анализ CSD или исключения всех каналов соответственно.

#### Регулировка параметров визуализации
- Поле `Contrast Coef.` предназначено для регулировки коэффициента контрастности при отображении данных CSD, позволяя улучшить различимость между областями высокой и низкой активности.
- Поле `Smooth Coef.` предоставляет возможность настроить коэффициент сглаживания, который может быть использован для уменьшения шума и улучшения общей читаемости данных CSD.

#### Применение настроек
- После установки необходимых параметров кнопка `Apply` используется для применения настроек CSD к выбранным каналам и обновления визуализации данных.



# Дополнительные возможности

## Конвертация в ZAV формат
Этот инструмент предназначен для преобразования данных электрофизиологических записей из формата NeuraLynx в формат мат-файлов ZAV, который совместим с системой просмотра LFP сигналов.
Для отрытия настроек конвертации выберите **File/convert NLX to ZAV**

![Конвертация в ZAV формат](https://github.com/ta3map/EasyViewer/blob/main/images/zavconvert.PNG)

### Выбор пути записи
- Кнопка `Select Record Path` позволяет пользователю выбрать папку, содержащую файлы NeuraLynx (.nlx), которые требуется конвертировать.

### Опции конвертации
- Флажок `Detect MUA` (multi-unit activity) активирует функцию обнаружения мультиунитовой активности во время конвертации. Это может быть полезно для последующего анализа нейронной активности.
- Поле `threshold (n*STD)` позволяет установить порог в множествах стандартного отклонения для детекции MUA.
  
### Выбор каналов
- Возможность выбрать `all channels` указывает на то, что конвертация будет применяться ко всем каналам в выбранной записи.
- Пользователь может также указать конкретные каналы для конвертации, если требуется более целенаправленный подход.

### Настройка частоты дискретизации
- Поле `Fs, Hz` (частота дискретизации) позволяет пользователю установить желаемую частоту дискретизации для выходных данных. По умолчанию установлено значение `1000 Гц`.

### Инициация процесса конвертации
- Кнопка `Start Conversion` запускает процесс преобразования данных. После нажатия начнется конвертация, и прогресс будет отображаться для пользователя.

## Файловый менеджер 
Файловый менеджер предназначен для навигации по интересуемым файлам помещенным в список.
Для открытия нажмите на кнопку `File manager` или выберите **File/file manager**. 

### Загрузка списка файлов
В открывшемся окне `File manager` выберите `Load list`, появится окно для выбора таблицы в формате **xlsx** в которой должны располагаться пути к файлам. 

Затем нужно выбрать в какой колонке находятся пути к интересуемым файлам. В примере ниже это пункт `event path`

![Файловый менеджер, выбор колонки](https://github.com/ta3map/EasyViewer/blob/main/images/FM_select_column.PNG)

После выбора колонки вы увидете загруженный список

![Файловый менеджер, загруженный список](https://github.com/ta3map/EasyViewer/blob/main/images/FM_ready.PNG)

Это может быть список с прямыми путями, как в примере. Но также можно указывать лишь названия ev-файлов. В таком случае поиск самого файла будет осуществляться внутри каталога в котором находится сам список.

### Открытие файла из файлового менеджера

Для открытия файла один раз кликните на строку с файлом и нажмите `Open file`.

### Дополнительные возможности файлового менеджера

Можно сохранять список в **xlsx** формат, нажав на кнопку `Save list`. 
Можно удалить ненужный файл из списка, нажав на кнопку `Delete file`.
Можно добавить новый файл в список, нажав на кнопку `Add file`.

### Настройки каналов
Боковая панель настроек каналов дает возможность выбора отображаемых каналов, масштабирования и изменения цветов для лучшего визуального различия сигналов.

![Настройки каналов](https://github.com/ta3map/EasyViewer/blob/main/images/ChannelSettings.PNG)

## Скрытие боковой панели
Выбрав в Меню `View` пункт `hide Channel Settings` вы скроете боковую панель с информацией о каналах. Это увеличит размер окна просматриваемого LFP сигнала. 

![Меню View](https://github.com/ta3map/EasyViewer/blob/main/images/hideMenu.png)

Затем нажатие на `show Channel Settings` в меню `View` вернет боковую панель.