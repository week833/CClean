@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 修復台股工具舊路徑相容性

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "EXTERNAL_ROOT=%REPO_ROOT%\external_repos"
set "LEGACY_GITHUB=%REPO_ROOT%\github_sources"

echo ============================================================
echo  修復舊路徑相容性
echo ============================================================
echo Repository：%REPO_ROOT%
echo.

if not exist "%EXTERNAL_ROOT%" mkdir "%EXTERNAL_ROOT%"
if not exist "%LEGACY_GITHUB%" mkdir "%LEGACY_GITHUB%"

rem 若 repository 不在舊的固定位置，且舊位置不存在，建立目錄連結。
if /I not "%REPO_ROOT%"=="D:\Downloads\stock" (
    if exist "D:\" (
        if not exist "D:\Downloads" mkdir "D:\Downloads" >nul 2>&1
        if not exist "D:\Downloads\stock" (
            echo [LINK] D:\Downloads\stock ^-^> %REPO_ROOT%
            mklink /J "D:\Downloads\stock" "%REPO_ROOT%" >nul 2>&1
            if !ERRORLEVEL! NEQ 0 echo [WARN] 無法建立 D:\Downloads\stock 相容連結，可能需要系統管理員權限。
        ) else (
            echo [KEEP] D:\Downloads\stock 已存在，不進行覆蓋。
        )
    )
)

echo.
echo [1/2] 建立 external_repos 舊版平面路徑連結...
call :ensure_junction "external_repos\FinMind" "external_repos\01_taiwan_stock_data\FinMind"
call :ensure_junction "external_repos\daily_stock_analysis" "external_repos\01_taiwan_stock_data\daily_stock_analysis"
call :ensure_junction "external_repos\stock-strategies-only" "external_repos\01_taiwan_stock_data\stock-strategies-only"
call :ensure_junction "external_repos\CasualMarket" "external_repos\01_taiwan_stock_data\CasualMarket"
call :ensure_junction "external_repos\twstock" "external_repos\01_taiwan_stock_data\twstock"
call :ensure_junction "external_repos\PyConTW2018Tutorial" "external_repos\01_taiwan_stock_data\PyConTW2018Tutorial"
call :ensure_junction "external_repos\yfinance" "external_repos\02_market_data_platforms\yfinance"
call :ensure_junction "external_repos\OpenBB" "external_repos\02_market_data_platforms\OpenBB"
call :ensure_junction "external_repos\qlib" "external_repos\03_ai_ml_forecasting\qlib"
call :ensure_junction "external_repos\FinRL" "external_repos\03_ai_ml_forecasting\FinRL"
call :ensure_junction "external_repos\darts" "external_repos\03_ai_ml_forecasting\darts"
call :ensure_junction "external_repos\mlforecast" "external_repos\03_ai_ml_forecasting\mlforecast"
call :ensure_junction "external_repos\neuralforecast" "external_repos\03_ai_ml_forecasting\neuralforecast"
call :ensure_junction "external_repos\statsforecast" "external_repos\03_ai_ml_forecasting\statsforecast"
call :ensure_junction "external_repos\LightGBM" "external_repos\03_ai_ml_forecasting\LightGBM"
call :ensure_junction "external_repos\xgboost" "external_repos\03_ai_ml_forecasting\xgboost"
call :ensure_junction "external_repos\catboost" "external_repos\03_ai_ml_forecasting\catboost"
call :ensure_junction "external_repos\optuna" "external_repos\03_ai_ml_forecasting\optuna"
call :ensure_junction "external_repos\shap" "external_repos\03_ai_ml_forecasting\shap"
call :ensure_junction "external_repos\freqtrade" "external_repos\03_ai_ml_forecasting\freqtrade"
call :ensure_junction "external_repos\vectorbt" "external_repos\04_backtesting_engines\vectorbt"
call :ensure_junction "external_repos\backtesting.py" "external_repos\04_backtesting_engines\backtesting-py"
call :ensure_junction "external_repos\Lean" "external_repos\04_backtesting_engines\Lean"
call :ensure_junction "external_repos\bt" "external_repos\04_backtesting_engines\bt"
call :ensure_junction "external_repos\zipline-reloaded" "external_repos\04_backtesting_engines\zipline-reloaded"
call :ensure_junction "external_repos\backtrader" "external_repos\04_backtesting_engines\backtrader"
call :ensure_junction "external_repos\ta-lib-python" "external_repos\05_indicators_factors_portfolio\ta-lib-python"
call :ensure_junction "external_repos\ta" "external_repos\05_indicators_factors_portfolio\ta"
call :ensure_junction "external_repos\alphalens-reloaded" "external_repos\05_indicators_factors_portfolio\alphalens-reloaded"
call :ensure_junction "external_repos\quantstats" "external_repos\05_indicators_factors_portfolio\quantstats"
call :ensure_junction "external_repos\pyfolio-reloaded" "external_repos\05_indicators_factors_portfolio\pyfolio-reloaded"
call :ensure_junction "external_repos\empyrical-reloaded" "external_repos\05_indicators_factors_portfolio\empyrical-reloaded"
call :ensure_junction "external_repos\ffn" "external_repos\05_indicators_factors_portfolio\ffn"
call :ensure_junction "external_repos\PyPortfolioOpt" "external_repos\05_indicators_factors_portfolio\PyPortfolioOpt"
call :ensure_junction "external_repos\Riskfolio-Lib" "external_repos\05_indicators_factors_portfolio\Riskfolio-Lib"
call :ensure_junction "external_repos\skfolio" "external_repos\05_indicators_factors_portfolio\skfolio"

echo.
echo [2/2] 建立早期 github_sources 路徑連結...
call :ensure_junction "github_sources\twstock" "external_repos\01_taiwan_stock_data\twstock"
call :ensure_junction "github_sources\tw_stocker" "external_repos\00_legacy_compat\tw_stocker"
call :ensure_junction "github_sources\python-stock-radar-" "external_repos\00_legacy_compat\python-stock-radar-"
call :ensure_junction "github_sources\TW-stock" "external_repos\00_legacy_compat\TW-stock"

echo.
echo ============================================================
echo  相容路徑修復完成
echo ============================================================
echo 已存在的實體資料夾不會被覆蓋。
echo 尚未下載的來源會顯示 SKIP，下載完成後可再次執行本工具。
echo.
pause
exit /b 0

:ensure_junction
set "LINK=%REPO_ROOT%\%~1"
set "TARGET=%REPO_ROOT%\%~2"

if not exist "%TARGET%" (
    echo [SKIP] 來源尚未下載：%~2
    exit /b 0
)

if exist "%LINK%" (
    echo [KEEP] 已存在：%~1
    exit /b 0
)

for %%I in ("%LINK%\..") do if not exist "%%~fI" mkdir "%%~fI" >nul 2>&1
mklink /J "%LINK%" "%TARGET%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [LINK] %~1 ^-^> %~2
) else (
    echo [WARN] 無法建立連結：%~1
)
exit /b 0
