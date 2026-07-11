@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 檢查台股工具環境與相容路徑

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "LOG_FILE=%REPO_ROOT%\stock_environment_check.log"
set /a ERRORS=0

(
echo ============================================================
echo 台股工具環境檢查
echo Repository: %REPO_ROOT%
echo Date: %DATE% %TIME%
echo ============================================================
) > "%LOG_FILE%"

call :check_file "STOCK_SETUP_MANAGER.cmd"
call :check_file "requirements.txt"
call :check_file "requirements_tw_stock_ai.txt"
call :check_file "install_tw_stock_ai_env.cmd"
call :check_file "DOWNLOAD_STOCK_SOURCES.cmd"
call :check_file "DOWNLOAD_LEGACY_SOURCES.cmd"
call :check_file "REPAIR_STOCK_PATHS.cmd"
call :check_file "VERIFY_STOCK_ENV.cmd"
call :check_file "scripts\clone_stock_analysis_repos.cmd"
call :check_file "scripts\setup\install_tw_stock_ai_env.cmd"
call :check_file "scripts\sources\clone_stock_analysis_repos.cmd"
call :check_file "scripts\sources\clone_legacy_compat_repos.cmd"
call :check_file "scripts\compat\repair_legacy_paths.cmd"
call :check_file "docs\legacy_compatibility.md"

if exist "%REPO_ROOT%\.venv\Scripts\python.exe" (
    echo [OK] .venv Python 已存在
    echo [OK] .venv Python 已存在 >> "%LOG_FILE%"
    "%REPO_ROOT%\.venv\Scripts\python.exe" -c "import FinMind, twstock, pandas, numpy, yfinance, requests, matplotlib, openpyxl; print('CORE_IMPORT_OK')" >> "%LOG_FILE%" 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo [OK] 核心套件匯入成功
    ) else (
        echo [FAIL] 核心套件匯入失敗，請重新執行安裝程式
        echo [FAIL] 核心套件匯入失敗 >> "%LOG_FILE%"
        set /a ERRORS+=1
    )
) else (
    echo [FAIL] 尚未建立 .venv；請執行 install_tw_stock_ai_env.cmd
    echo [FAIL] 尚未建立 .venv >> "%LOG_FILE%"
    set /a ERRORS+=1
)

if exist "%REPO_ROOT%\external_repos" (
    echo [OK] external_repos 已存在
    echo [OK] external_repos 已存在 >> "%LOG_FILE%"
) else (
    echo [INFO] external_repos 尚未建立；需要外部來源時再下載
    echo [INFO] external_repos 尚未建立 >> "%LOG_FILE%"
)

echo.
if !ERRORS! EQU 0 (
    echo 檢查完成：未發現阻斷性問題，不需要重新安裝核心環境。
) else (
    echo 檢查完成：發現 !ERRORS! 個問題，請使用 STOCK_SETUP_MANAGER.cmd 修復。
)
echo 紀錄檔：%LOG_FILE%

if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b !ERRORS!

:check_file
if exist "%REPO_ROOT%\%~1" (
    echo [OK] %~1
    echo [OK] %~1 >> "%LOG_FILE%"
) else (
    echo [FAIL] 缺少 %~1
    echo [FAIL] 缺少 %~1 >> "%LOG_FILE%"
    set /a ERRORS+=1
)
exit /b 0
