@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 下載舊版相容股票來源

set /a FAILED_COUNT=0
set /a SUCCESS_COUNT=0

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "EXTERNAL_ROOT=%REPO_ROOT%\external_repos"

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 找不到 Git，請先安裝 Git for Windows。
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

if not exist "%EXTERNAL_ROOT%" mkdir "%EXTERNAL_ROOT%"
if errorlevel 1 (
    echo [ERROR] 無法建立外部來源資料夾：%EXTERNAL_ROOT%
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

echo ============================================================
echo 下載舊版安裝程式曾使用的 GitHub 來源
echo ============================================================
echo 只會寫入：%EXTERNAL_ROOT%
echo 不會搬移或刪除其他資料夾。
echo.

call :clone_or_pull "01_taiwan_stock_data\twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "00_legacy_compat\tw_stocker" "https://github.com/voidful/tw_stocker.git"
call :clone_or_pull "00_legacy_compat\python-stock-radar-" "https://github.com/william911530-cmyk/python-stock-radar-.git"
call :clone_or_pull "00_legacy_compat\TW-stock" "https://github.com/k66inthesky/TW-stock.git"

if exist "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd" (
    call "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd"
    if errorlevel 1 set /a FAILED_COUNT+=1
)

echo.
echo ============================================================
echo Legacy 來源處理完成：成功 !SUCCESS_COUNT!，失敗 !FAILED_COUNT!
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
    echo [ERROR] 無法建立資料夾：%TARGET%
    set /a FAILED_COUNT+=1
    exit /b 0
)

if exist "%TARGET%\.git" (
    echo [UPDATE] %RELATIVE_PATH%
    git -C "%TARGET%" pull --ff-only
    if errorlevel 1 (
        echo [ERROR] 更新失敗：%TARGET%
        set /a FAILED_COUNT+=1
    ) else (
        set /a SUCCESS_COUNT+=1
    )
) else (
    if exist "%TARGET%" (
        echo [ERROR] 目標存在但不是 Git repository，未修改：%TARGET%
        set /a FAILED_COUNT+=1
    ) else (
        echo [CLONE] %RELATIVE_PATH%
        git clone "%URL%" "%TARGET%"
        if errorlevel 1 (
            echo [ERROR] 下載失敗：%URL%
            set /a FAILED_COUNT+=1
        ) else (
            set /a SUCCESS_COUNT+=1
        )
    )
)
exit /b 0
