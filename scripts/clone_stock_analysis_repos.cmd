@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title Clone stock analysis GitHub repositories

echo ============================================================
echo  股票分析 GitHub 參考專案下載 / 更新工具
echo ============================================================
echo.

where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 找不到 git。
    echo 請先安裝 Git for Windows：
    echo https://git-scm.com/download/win
    pause
    exit /b 1
)

set "ROOT_DIR=%~dp0.."
for %%I in ("%ROOT_DIR%") do set "ROOT_DIR=%%~fI"
set "EXTERNAL_DIR=%ROOT_DIR%\external_repos"

if not exist "%EXTERNAL_DIR%" mkdir "%EXTERNAL_DIR%"

call :clone_or_pull "FinMind" "https://github.com/FinMind/FinMind.git"
call :clone_or_pull "daily_stock_analysis" "https://github.com/ZhuLinsen/daily_stock_analysis.git"
call :clone_or_pull "stock-strategies-only" "https://github.com/kevin801221/stock-strategies-only.git"
call :clone_or_pull "CasualMarket" "https://github.com/sacahan/CasualMarket.git"
call :clone_or_pull "twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "PyConTW2018Tutorial" "https://github.com/victorgau/PyConTW2018Tutorial.git"

echo.
echo ============================================================
echo  完成
echo ============================================================
echo  外部專案位置：
echo  %EXTERNAL_DIR%
echo.
pause
exit /b 0

:clone_or_pull
set "NAME=%~1"
set "URL=%~2"
set "TARGET=%EXTERNAL_DIR%\%NAME%"

echo.
echo ------------------------------------------------------------
echo [INFO] %NAME%
echo ------------------------------------------------------------

if exist "%TARGET%\.git" (
    echo [INFO] 已存在，執行 git pull 更新...
    pushd "%TARGET%"
    git pull --ff-only
    if %ERRORLEVEL% NEQ 0 (
        echo [WARN] git pull 失敗，請手動檢查：%TARGET%
    )
    popd
) else (
    if exist "%TARGET%" (
        echo [WARN] 目標資料夾已存在但不是 git repo，略過：%TARGET%
    ) else (
        echo [INFO] clone %URL%
        git clone "%URL%" "%TARGET%"
        if %ERRORLEVEL% NEQ 0 (
            echo [ERROR] clone 失敗：%URL%
        )
    )
)
exit /b 0
