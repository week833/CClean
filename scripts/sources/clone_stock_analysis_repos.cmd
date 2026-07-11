@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 股票分析外部來源分類下載工具

set /a FAILED_COUNT=0
set /a SUCCESS_COUNT=0

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 找不到 Git，請先安裝 Git for Windows。
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

set "ROOT_DIR=%~dp0..\.."
for %%I in ("%ROOT_DIR%") do set "ROOT_DIR=%%~fI"
set "EXTERNAL_DIR=%ROOT_DIR%\external_repos"

if not exist "%EXTERNAL_DIR%" mkdir "%EXTERNAL_DIR%"
if errorlevel 1 (
    echo [ERROR] 無法建立外部來源資料夾：%EXTERNAL_DIR%
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

echo ============================================================
echo  股票分析 GitHub 來源下載 / 更新工具
echo ============================================================
echo  所有來源只會寫入：%EXTERNAL_DIR%
echo  不會搬移或刪除既有舊資料夾。
echo.

call :clone_or_pull "01_taiwan_stock_data\FinMind" "https://github.com/FinMind/FinMind.git"
call :clone_or_pull "01_taiwan_stock_data\daily_stock_analysis" "https://github.com/ZhuLinsen/daily_stock_analysis.git"
call :clone_or_pull "01_taiwan_stock_data\stock-strategies-only" "https://github.com/kevin801221/stock-strategies-only.git"
call :clone_or_pull "01_taiwan_stock_data\CasualMarket" "https://github.com/sacahan/CasualMarket.git"
call :clone_or_pull "01_taiwan_stock_data\twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "01_taiwan_stock_data\PyConTW2018Tutorial" "https://github.com/victorgau/PyConTW2018Tutorial.git"
call :clone_or_pull "02_market_data_platforms\yfinance" "https://github.com/ranaroussi/yfinance.git"
call :clone_or_pull "02_market_data_platforms\OpenBB" "https://github.com/OpenBB-finance/OpenBB.git"
call :clone_or_pull "03_ai_ml_forecasting\qlib" "https://github.com/microsoft/qlib.git"
call :clone_or_pull "03_ai_ml_forecasting\FinRL" "https://github.com/AI4Finance-Foundation/FinRL.git"
call :clone_or_pull "03_ai_ml_forecasting\darts" "https://github.com/unit8co/darts.git"
call :clone_or_pull "03_ai_ml_forecasting\mlforecast" "https://github.com/Nixtla/mlforecast.git"
call :clone_or_pull "03_ai_ml_forecasting\neuralforecast" "https://github.com/Nixtla/neuralforecast.git"
call :clone_or_pull "03_ai_ml_forecasting\statsforecast" "https://github.com/Nixtla/statsforecast.git"
call :clone_or_pull "03_ai_ml_forecasting\LightGBM" "https://github.com/lightgbm-org/LightGBM.git"
call :clone_or_pull "03_ai_ml_forecasting\xgboost" "https://github.com/dmlc/xgboost.git"
call :clone_or_pull "03_ai_ml_forecasting\catboost" "https://github.com/catboost/catboost.git"
call :clone_or_pull "03_ai_ml_forecasting\optuna" "https://github.com/optuna/optuna.git"
call :clone_or_pull "03_ai_ml_forecasting\shap" "https://github.com/shap/shap.git"
call :clone_or_pull "03_ai_ml_forecasting\freqtrade" "https://github.com/freqtrade/freqtrade.git"
call :clone_or_pull "04_backtesting_engines\vectorbt" "https://github.com/polakowo/vectorbt.git"
call :clone_or_pull "04_backtesting_engines\backtesting-py" "https://github.com/kernc/backtesting.py.git"
call :clone_or_pull "04_backtesting_engines\Lean" "https://github.com/QuantConnect/Lean.git"
call :clone_or_pull "04_backtesting_engines\bt" "https://github.com/pmorissette/bt.git"
call :clone_or_pull "04_backtesting_engines\zipline-reloaded" "https://github.com/stefan-jansen/zipline-reloaded.git"
call :clone_or_pull "04_backtesting_engines\backtrader" "https://github.com/mementum/backtrader.git"
call :clone_or_pull "05_indicators_factors_portfolio\ta-lib-python" "https://github.com/TA-Lib/ta-lib-python.git"
call :clone_or_pull "05_indicators_factors_portfolio\ta" "https://github.com/bukosabino/ta.git"
call :clone_or_pull "05_indicators_factors_portfolio\alphalens-reloaded" "https://github.com/stefan-jansen/alphalens-reloaded.git"
call :clone_or_pull "05_indicators_factors_portfolio\quantstats" "https://github.com/ranaroussi/quantstats.git"
call :clone_or_pull "05_indicators_factors_portfolio\pyfolio-reloaded" "https://github.com/stefan-jansen/pyfolio-reloaded.git"
call :clone_or_pull "05_indicators_factors_portfolio\empyrical-reloaded" "https://github.com/stefan-jansen/empyrical-reloaded.git"
call :clone_or_pull "05_indicators_factors_portfolio\ffn" "https://github.com/pmorissette/ffn.git"
call :clone_or_pull "05_indicators_factors_portfolio\PyPortfolioOpt" "https://github.com/PyPortfolio/PyPortfolioOpt.git"
call :clone_or_pull "05_indicators_factors_portfolio\Riskfolio-Lib" "https://github.com/dcajasn/Riskfolio-Lib.git"
call :clone_or_pull "05_indicators_factors_portfolio\skfolio" "https://github.com/skfolio/skfolio.git"

if exist "%ROOT_DIR%\scripts\compat\repair_legacy_paths.cmd" (
    call "%ROOT_DIR%\scripts\compat\repair_legacy_paths.cmd"
    if errorlevel 1 set /a FAILED_COUNT+=1
)

echo.
echo ============================================================
echo 來源處理完成：成功 !SUCCESS_COUNT!，失敗 !FAILED_COUNT!
echo 位置：%EXTERNAL_DIR%
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
set "TARGET=%EXTERNAL_DIR%\%RELATIVE_PATH%"

for %%I in ("%TARGET%\..") do if not exist "%%~fI" mkdir "%%~fI"
if errorlevel 1 (
    echo [ERROR] 無法建立資料夾：%TARGET%
    set /a FAILED_COUNT+=1
    exit /b 0
)

echo.
echo [INFO] %RELATIVE_PATH%

if exist "%TARGET%\.git" (
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
