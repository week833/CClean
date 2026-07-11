@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 下載舊版相容股票來源

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "EXTERNAL_ROOT=%REPO_ROOT%\external_repos"

where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 找不到 Git，請先安裝 Git for Windows。
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

echo ============================================================
echo  下載舊版安裝程式曾使用的 GitHub 來源
echo ============================================================
echo.

call :clone_or_pull "01_taiwan_stock_data\twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "00_legacy_compat\tw_stocker" "https://github.com/voidful/tw_stocker.git"
call :clone_or_pull "00_legacy_compat\python-stock-radar-" "https://github.com/william911530-cmyk/python-stock-radar-.git"
call :clone_or_pull "00_legacy_compat\TW-stock" "https://github.com/k66inthesky/TW-stock.git"

if exist "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd" (
    call "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd"
)

exit /b 0

:clone_or_pull
set "RELATIVE_PATH=%~1"
set "URL=%~2"
set "TARGET=%EXTERNAL_ROOT%\%RELATIVE_PATH%"
for %%I in ("%TARGET%\..") do if not exist "%%~fI" mkdir "%%~fI"

if exist "%TARGET%\.git" (
    echo [UPDATE] %RELATIVE_PATH%
    pushd "%TARGET%"
    git pull --ff-only
    if !ERRORLEVEL! NEQ 0 echo [WARN] 更新失敗：%TARGET%
    popd
) else (
    if exist "%TARGET%" (
        echo [WARN] 目標存在但不是 Git repository：%TARGET%
    ) else (
        echo [CLONE] %RELATIVE_PATH%
        git clone "%URL%" "%TARGET%"
        if !ERRORLEVEL! NEQ 0 echo [ERROR] 下載失敗：%URL%
    )
)
exit /b 0
