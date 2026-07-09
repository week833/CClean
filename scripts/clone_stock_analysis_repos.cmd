@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title Clone complete stock analysis GitHub repositories

echo ============================================================
echo  完整股票分析 GitHub 參考專案下載 / 更新工具
echo ============================================================
echo.
echo  這個腳本會下載或更新 36 個股票分析 / 量化 / 預測相關 GitHub repo。
echo  外部專案會放在 external_repos，且已由 .gitignore 排除。
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
echo [GROUP] A. 台股與股票資料 / 既有參考來源
call :clone_or_pull "FinMind" "https://github.com/FinMind/FinMind.git"
call :clone_or_pull "daily_stock_analysis" "https://github.com/ZhuLinsen/daily_stock_analysis.git"
call :clone_or_pull "stock-strategies-only" "https://github.com/kevin801221/stock-strategies-only.git"
call :clone_or_pull "CasualMarket" "https://github.com/sacahan/CasualMarket.git"
call :clone_or_pull "twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "PyConTW2018Tutorial" "https://github.com/victorgau/PyConTW2018Tutorial.git"

echo.
echo [GROUP] B. 金融資料 / 市場研究平台
call :clone_or_pull "yfinance" "https://github.com/ranaroussi/yfinance.git"
call :clone_or_pull "OpenBB" "https://github.com/OpenBB-finance/OpenBB.git"

echo.
echo [GROUP] C. AI / ML / 時間序列預測框架
call :clone_or_pull "qlib" "https://github.com/microsoft/qlib.git"
call :clone_or_pull "FinRL" "https://github.com/AI4Finance-Foundation/FinRL.git"
call :clone_or_pull "darts" "https://github.com/unit8co/darts.git"
call :clone_or_pull "mlforecast" "https://github.com/Nixtla/mlforecast.git"
call :clone_or_pull "neuralforecast" "https://github.com/Nixtla/neuralforecast.git"
call :clone_or_pull "statsforecast" "https://github.com/Nixtla/statsforecast.git"
call :clone_or_pull "LightGBM" "https://github.com/lightgbm-org/LightGBM.git"
call :clone_or_pull "xgboost" "https://github.com/dmlc/xgboost.git"
call :clone_or_pull "catboost" "https://github.com/catboost/catboost.git"
call :clone_or_pull "optuna" "https://github.com/optuna/optuna.git"
call :clone_or_pull "shap" "https://github.com/shap/shap.git"
call :clone_or_pull "freqtrade" "https://github.com/freqtrade/freqtrade.git"

echo.
echo [GROUP] D. 回測引擎 / 策略測試
call :clone_or_pull "vectorbt" "https://github.com/polakowo/vectorbt.git"
call :clone_or_pull "backtesting.py" "https://github.com/kernc/backtesting.py.git"
call :clone_or_pull "Lean" "https://github.com/QuantConnect/Lean.git"
call :clone_or_pull "bt" "https://github.com/pmorissette/bt.git"
call :clone_or_pull "zipline-reloaded" "https://github.com/stefan-jansen/zipline-reloaded.git"
call :clone_or_pull "backtrader" "https://github.com/mementum/backtrader.git"

echo.
echo [GROUP] E. 技術指標 / 因子分析 / 績效報告 / 投組最佳化
call :clone_or_pull "ta-lib-python" "https://github.com/TA-Lib/ta-lib-python.git"
call :clone_or_pull "ta" "https://github.com/bukosabino/ta.git"
call :clone_or_pull "alphalens-reloaded" "https://github.com/stefan-jansen/alphalens-reloaded.git"
call :clone_or_pull "quantstats" "https://github.com/ranaroussi/quantstats.git"
call :clone_or_pull "pyfolio-reloaded" "https://github.com/stefan-jansen/pyfolio-reloaded.git"
call :clone_or_pull "empyrical-reloaded" "https://github.com/stefan-jansen/empyrical-reloaded.git"
call :clone_or_pull "ffn" "https://github.com/pmorissette/ffn.git"
call :clone_or_pull "PyPortfolioOpt" "https://github.com/PyPortfolio/PyPortfolioOpt.git"
call :clone_or_pull "Riskfolio-Lib" "https://github.com/dcajasn/Riskfolio-Lib.git"
call :clone_or_pull "skfolio" "https://github.com/skfolio/skfolio.git"

echo.
echo ============================================================
echo  完成
echo ============================================================
echo  外部專案位置：
echo  %EXTERNAL_DIR%
echo.
echo  注意：OpenBB、vectorbt、Lean、freqtrade、catboost、darts 等 repo 體積較大，下載時間可能較久。
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
