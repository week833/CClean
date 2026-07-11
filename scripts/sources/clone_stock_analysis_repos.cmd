@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 股票分析外部來源分類下載工具

echo ============================================================
echo  股票分析 GitHub 來源下載 / 更新工具
echo ============================================================
echo.
echo  所有來源會依分類與來源名稱存入獨立資料夾。
echo  若偵測到舊版平面資料夾或 github_sources，會優先搬移，不重複下載。
echo.
where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 找不到 Git，請先安裝 Git for Windows。
    echo https://git-scm.com/download/win
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

set "ROOT_DIR=%~dp0..\.."
for %%I in ("%ROOT_DIR%") do set "ROOT_DIR=%%~fI"
set "EXTERNAL_DIR=%ROOT_DIR%\external_repos"
set "OLD_GITHUB_DIR=%ROOT_DIR%\github_sources"

if not exist "%EXTERNAL_DIR%" mkdir "%EXTERNAL_DIR%"

echo.
echo [GROUP] 01_taiwan_stock_data - 台股與既有股票分析來源
call :clone_or_pull "01_taiwan_stock_data\FinMind" "https://github.com/FinMind/FinMind.git"
call :clone_or_pull "01_taiwan_stock_data\daily_stock_analysis" "https://github.com/ZhuLinsen/daily_stock_analysis.git"
call :clone_or_pull "01_taiwan_stock_data\stock-strategies-only" "https://github.com/kevin801221/stock-strategies-only.git"
call :clone_or_pull "01_taiwan_stock_data\CasualMarket" "https://github.com/sacahan/CasualMarket.git"
call :clone_or_pull "01_taiwan_stock_data\twstock" "https://github.com/mlouielu/twstock.git"
call :clone_or_pull "01_taiwan_stock_data\PyConTW2018Tutorial" "https://github.com/victorgau/PyConTW2018Tutorial.git"

echo.
echo [GROUP] 02_market_data_platforms - 金融資料與市場研究平台
call :clone_or_pull "02_market_data_platforms\yfinance" "https://github.com/ranaroussi/yfinance.git"
call :clone_or_pull "02_market_data_platforms\OpenBB" "https://github.com/OpenBB-finance/OpenBB.git"

echo.
echo [GROUP] 03_ai_ml_forecasting - AI、機器學習與時間序列預測
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

echo.
echo [GROUP] 04_backtesting_engines - 回測引擎與策略測試
call :clone_or_pull "04_backtesting_engines\vectorbt" "https://github.com/polakowo/vectorbt.git"
call :clone_or_pull "04_backtesting_engines\backtesting-py" "https://github.com/kernc/backtesting.py.git"
call :clone_or_pull "04_backtesting_engines\Lean" "https://github.com/QuantConnect/Lean.git"
call :clone_or_pull "04_backtesting_engines\bt" "https://github.com/pmorissette/bt.git"
call :clone_or_pull "04_backtesting_engines\zipline-reloaded" "https://github.com/stefan-jansen/zipline-reloaded.git"
call :clone_or_pull "04_backtesting_engines\backtrader" "https://github.com/mementum/backtrader.git"

echo.
echo [GROUP] 05_indicators_factors_portfolio - 技術指標、因子、績效與投組風控
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
)

echo.
echo ============================================================
echo  全部來源處理完成
echo ============================================================
echo 位置：%EXTERNAL_DIR%
echo.
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 0

:clone_or_pull
set "RELATIVE_PATH=%~1"
set "URL=%~2"
set "TARGET=%EXTERNAL_DIR%\%RELATIVE_PATH%"
for %%I in ("%RELATIVE_PATH%") do set "SOURCE_NAME=%%~nxI"
set "OLD_FLAT=%EXTERNAL_DIR%\!SOURCE_NAME!"
set "OLD_GITHUB=%OLD_GITHUB_DIR%\!SOURCE_NAME!"

for %%I in ("%TARGET%\..") do if not exist "%%~fI" mkdir "%%~fI"

if not exist "%TARGET%" (
    if exist "!OLD_FLAT!\.git" (
        echo [MIGRATE] !OLD_FLAT! ^-^> %TARGET%
        move "!OLD_FLAT!" "%TARGET%" >nul
    ) else if exist "!OLD_GITHUB!\.git" (
        echo [MIGRATE] !OLD_GITHUB! ^-^> %TARGET%
        move "!OLD_GITHUB!" "%TARGET%" >nul
    )
)

echo.
echo ------------------------------------------------------------
echo [INFO] %RELATIVE_PATH%
echo ------------------------------------------------------------

if exist "%TARGET%\.git" (
    pushd "%TARGET%"
    git pull --ff-only
    if !ERRORLEVEL! NEQ 0 echo [WARN] 更新失敗：%TARGET%
    popd
) else (
    if exist "%TARGET%" (
        echo [WARN] 目標存在但不是 Git repository，略過：%TARGET%
    ) else (
        git clone "%URL%" "%TARGET%"
        if !ERRORLEVEL! NEQ 0 echo [ERROR] 下載失敗：%URL%
    )
)
exit /b 0
