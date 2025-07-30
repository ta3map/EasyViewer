@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
echo ========================================
echo Анализ структуры MAT файла
echo ========================================
echo.

REM Активация виртуального окружения
echo Активация виртуального окружения...
call venv\Scripts\activate.bat

REM Проверка аргументов командной строки
if "%~1"=="" (
    echo Поиск MAT файлов в папке zav_data_example...
    echo.
    
    REM Проверяем существование папки
    if not exist "zav_data_example" (
        echo ОШИБКА: Папка zav_data_example не найдена!
        echo Убедитесь, что папка существует в текущей директории.
        pause
        exit /b 1
    )
    
    REM Ищем MAT файлы
    set "file_count=0"
    set "file_list="
    
    for %%f in (zav_data_example\*.mat) do (
        set /a file_count+=1
        set "file_list=!file_list! %%f"
        echo !file_count!. %%~nxf
    )
    
    if %file_count%==0 (
        echo В папке zav_data_example не найдено MAT файлов!
        pause
        exit /b 1
    )
    
    echo.
    echo Найдено файлов: %file_count%
    echo.
    
    REM Запрашиваем выбор файла
    :input_loop
    set /p choice="Введите номер файла для анализа (1-%file_count%): "
    
    REM Проверяем корректность ввода
    set "valid_choice=0"
    for /l %%i in (1,1,%file_count%) do (
        if "!choice!"=="%%i" set "valid_choice=1"
    )
    
    if !valid_choice!==0 (
        echo Неверный номер! Введите число от 1 до %file_count%
        goto input_loop
    )
    
    REM Выбираем файл по номеру
    set "current_file=0"
    for %%f in (zav_data_example\*.mat) do (
        set /a current_file+=1
        if !current_file!==!choice! (
            echo.
            echo Выбран файл: %%~nxf
            echo.
            python view_mat_structure.py "%%f"
            goto end_analysis
        )
    )
    
) else (
    echo Запуск анализа файла: %1
    python view_mat_structure.py "%1"
)

:end_analysis
echo.
echo ========================================
echo Анализ завершен
echo ========================================
echo.
pause 