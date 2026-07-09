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

echo.
echo [GROUP] 台股與股票資料 / 既有參考來源
call :clone_or_pull "FinMind" "https://github.com/FinMind/FinMind.git"
call :clone_or_pull "daily_stock_analysis" "https://github.com/ZhuLinsen/daily_stock_analysis.git"
call :clone_or_pull "stock-strategies-only" "https://github.com/kevin801221/stock-strategies-only.git"
call :clone_or_pull "CasualMarket" "https://github.com/sacahan/CasualMarket.git"
call :clone_or_pull "twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "PyConTW2018Tutorial" "https://github.com/victorgau/PyConTW2018Tutorial.git"

echo.
echo [GROUP] AI / ML / 量化研究與預測框架
call :clone_or_pull "qlib" "https://github.com/microsoft/qlib.git"
call :clone_or_pull "FinRL" "https://github.com/AI4Finance-Foundation/FinRL.git"
call :clone_or_pull "OpenBB" "https://github.com/OpenBB-finance/OpenBB.git"
call :clone_or_pull "freqtrade" "https://github.com/freqtrade/freqtrade.git"

echo.
echo [GROUP] 回測引擎 / 策略測試
call :clone_or_pull "vectorbt" "https://github.com/polakowo/vectorbt.git"
call :clone_or_pull "backtesting.py" "https://github.com/kernc/backtesting.py.git"
call :clone_or_pull "Lean" "https://github.com/QuantConnect/Lean.git"
call :clone_or_pull "bt" "https://github.com/pmorissette/bt.git"
call :clone_or_pull "zipline-reloaded" "https://github.com/stefan-jansen/zipline-reloaded.git"
call :clone_or_pull "backtrader" "https://github.com/mementum/backtrader.git"

echo.
echo [GROUP] 技術指標 / 績效報告 / 投組最佳化
call :clone_or_pull "yfinance" "https://github.com/ranaroussi/yfinance.git"
call :clone_or_pull "ta" "https://github.com/bukosabino/ta.git"
call :clone_or_pull "quantstats" "https://github.com/ranaroussi/quantstats.git"
call :clone_or_pull "skfolio" "https://github.com/skfolio/skfolio.git"

echo.
echo ============================================================
echo  完成
echo ============================================================
echo  外部專案位置：
echo  %EXTERNAL_DIR%
echo.
echo  注意：OpenBB、vectorbt、Lean、freqtrade 等 repo 體積較大，下載時間可能較久。
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
