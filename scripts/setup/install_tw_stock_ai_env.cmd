@echo off
chcp 65001 >nul
setlocal EnableExtensions

title D:\stock 台股 AI 核心環境安裝程式

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "VENV_DIR=%REPO_ROOT%\.venv"
set "LOG_FILE=%REPO_ROOT%\install_tw_stock_ai_env.log"

echo ============================================================
echo  D:\stock 台股 AI 核心環境安裝程式
echo ============================================================
echo Repository：%REPO_ROOT%
echo 虛擬環境：%VENV_DIR%
echo.

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set "PY_CMD=py -3"
) else (
    where python >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        set "PY_CMD=python"
    ) else (
        echo [ERROR] 找不到 Python，請先執行根目錄 INSTALL_D_STOCK_ENV.cmd。
        if not defined STOCK_TOOLKIT_NO_PAUSE pause
        exit /b 1
    )
)

cd /d "%REPO_ROOT%" || exit /b 1

echo [1/7] 建立虛擬環境...
if not exist "%VENV_DIR%\Scripts\python.exe" (
    %PY_CMD% -m venv "%VENV_DIR%" >> "%LOG_FILE%" 2>&1
    if %ERRORLEVEL% NEQ 0 goto :error
) else (
    echo [KEEP] 已存在 .venv，不會刪除原環境。
)

echo [2/7] 啟用虛擬環境...
call "%VENV_DIR%\Scripts\activate.bat" || goto :error

echo [3/7] 更新 pip / setuptools / wheel...
python -m pip install --upgrade pip setuptools wheel >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo [4/7] 安裝 requirements.txt...
python -m pip install -r "%REPO_ROOT%\requirements.txt" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo [5/7] 測試核心套件...
python -c "import FinMind, twstock, pandas, numpy, yfinance, requests, matplotlib, openpyxl; print('CORE_IMPORT_OK')" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo [6/7] 設定 Windows 環境變數與 PATH...
if exist "%REPO_ROOT%\scripts\setup\configure_windows_environment.cmd" (
    set "LOCAL_NO_PAUSE="
    if not defined STOCK_TOOLKIT_NO_PAUSE (
        set "STOCK_TOOLKIT_NO_PAUSE=1"
        set "LOCAL_NO_PAUSE=1"
    )
    call "%REPO_ROOT%\scripts\setup\configure_windows_environment.cmd"
    if %ERRORLEVEL% NEQ 0 goto :error_restore_pause
    if defined LOCAL_NO_PAUSE set "STOCK_TOOLKIT_NO_PAUSE="
)

echo [7/7] 修復來源舊路徑相容性...
if exist "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd" (
    set "LOCAL_NO_PAUSE="
    if not defined STOCK_TOOLKIT_NO_PAUSE (
        set "STOCK_TOOLKIT_NO_PAUSE=1"
        set "LOCAL_NO_PAUSE=1"
    )
    call "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd"
    if defined LOCAL_NO_PAUSE set "STOCK_TOOLKIT_NO_PAUSE="
)

echo.
echo 安裝完成。
echo Repository：%REPO_ROOT%
echo Python：%VENV_DIR%\Scripts\python.exe
echo 紀錄檔：%LOG_FILE%
echo.
echo 新開啟的應用程式可使用 STOCK_HOME 與 STOCK_PYTHON 環境變數。
echo 若要下載外部來源，執行：DOWNLOAD_STOCK_SOURCES.cmd
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 0

:error_restore_pause
if defined LOCAL_NO_PAUSE set "STOCK_TOOLKIT_NO_PAUSE="
:error
echo.
echo [ERROR] 安裝失敗，請查看：
echo %LOG_FILE%
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 1
