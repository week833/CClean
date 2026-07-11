@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Legacy stock source downloader

set /a FAILED_COUNT=0
set /a SUCCESS_COUNT=0

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "EXTERNAL_ROOT=%REPO_ROOT%\external_repos"

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git was not found. Install Git for Windows first.
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

if not exist "%EXTERNAL_ROOT%" mkdir "%EXTERNAL_ROOT%"
if errorlevel 1 (
    echo [ERROR] Could not create external source directory: %EXTERNAL_ROOT%
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

echo ============================================================
echo Legacy compatibility source downloader
echo ============================================================
echo Only small compatibility repositories are included.
echo The oversized voidful/tw_stocker repository is excluded.
echo All sources are written only under: %EXTERNAL_ROOT%
echo Existing folders are not moved or deleted.
echo.

call :clone_or_pull "01_taiwan_stock_data\twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "00_legacy_compat\python-stock-radar-" "https://github.com/william911530-cmyk/python-stock-radar-.git"
call :clone_or_pull "00_legacy_compat\TW-stock" "https://github.com/k66inthesky/TW-stock.git"

if exist "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd" (
    call "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd"
    if errorlevel 1 set /a FAILED_COUNT+=1
)

echo.
echo ============================================================
echo Legacy source processing complete: success !SUCCESS_COUNT!, failed !FAILED_COUNT!
echo ============================================================

if !FAILED_COUNT! GTR 0 (
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 0

:clone_or_pull
set "RELATIVE_PATH=%~1"
set "URL=%~2"
set "TARGET=%EXTERNAL_ROOT%\%RELATIVE_PATH%"

for %%I in ("%TARGET%\..") do if not exist "%%~fI" mkdir "%%~fI"
if errorlevel 1 (
    echo [ERROR] Could not create directory: %TARGET%
    set /a FAILED_COUNT+=1
    exit /b 0
)

if exist "%TARGET%\.git" (
    echo [UPDATE] %RELATIVE_PATH%
    git -C "%TARGET%" pull --ff-only
    if errorlevel 1 (
        echo [ERROR] Update failed: %TARGET%
        set /a FAILED_COUNT+=1
    ) else (
        set /a SUCCESS_COUNT+=1
    )
) else (
    if exist "%TARGET%" (
        echo [ERROR] Target exists but is not a Git repository. It was not modified: %TARGET%
        set /a FAILED_COUNT+=1
    ) else (
        echo [CLONE] %RELATIVE_PATH%
        git clone --depth 1 "%URL%" "%TARGET%"
        if errorlevel 1 (
            echo [ERROR] Clone failed: %URL%
            set /a FAILED_COUNT+=1
        ) else (
            set /a SUCCESS_COUNT+=1
        )
    )
)
exit /b 0
