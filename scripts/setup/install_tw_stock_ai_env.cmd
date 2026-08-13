@echo off
chcp 65001 >nul
setlocal EnableExtensions

title D:\stock Taiwan stock AI core environment installer

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "VENV_DIR=%REPO_ROOT%\.venv"
set "LOG_FILE=%REPO_ROOT%\install_tw_stock_ai_env.log"

echo ============================================================
echo  D:\stock Taiwan stock AI core environment installer
echo ============================================================
echo Repository: %REPO_ROOT%
echo Virtual environment: %VENV_DIR%
echo.

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set "PY_CMD=py -3"
) else (
    where python >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        set "PY_CMD=python"
    ) else (
        echo [ERROR] Python was not found; run root INSTALL_D_STOCK_ENV.cmd first.
        if not defined STOCK_TOOLKIT_NO_PAUSE pause
        exit /b 1
    )
)

cd /d "%REPO_ROOT%" || exit /b 1

echo [1/7] Creating virtual environment...
if not exist "%VENV_DIR%\Scripts\python.exe" (
    %PY_CMD% -m venv "%VENV_DIR%" >> "%LOG_FILE%" 2>&1
    if %ERRORLEVEL% NEQ 0 goto :error
) else (
    echo [KEEP] Existing .venv retained; the environment will not be deleted.
)

echo [2/7] Activating virtual environment...
call "%VENV_DIR%\Scripts\activate.bat" || goto :error

echo [3/7] Updating pip / setuptools / wheel...
python -m pip install --upgrade pip setuptools wheel >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo [4/7] Installing requirements.txt...
python -m pip install -r "%REPO_ROOT%\requirements.txt" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo [5/7] Testing core packages...
python -c "import FinMind, twstock, pandas, numpy, yfinance, requests, matplotlib, openpyxl; print('CORE_IMPORT_OK')" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo [6/7] Configuring Windows environment variables and PATH...
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

echo [7/7] Checking legacy source compatibility paths (read-only; no junctions will be created)...
if exist "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd" (
    set "LOCAL_NO_PAUSE="
    if not defined STOCK_TOOLKIT_NO_PAUSE (
        set "STOCK_TOOLKIT_NO_PAUSE=1"
        set "LOCAL_NO_PAUSE=1"
    )
    call "%REPO_ROOT%\scripts\compat\repair_legacy_paths.cmd" --check
    if errorlevel 1 (
        echo [WARN] Legacy path check failed; no junctions were created or repaired.
        if defined LOCAL_NO_PAUSE set "STOCK_TOOLKIT_NO_PAUSE="
        goto :error
    )
    if defined LOCAL_NO_PAUSE set "STOCK_TOOLKIT_NO_PAUSE="
)

echo.
echo Installation completed.
echo Repository: %REPO_ROOT%
echo Python: %VENV_DIR%\Scripts\python.exe
echo Log file: %LOG_FILE%
echo.
echo Newly opened applications can use STOCK_HOME and STOCK_PYTHON.
echo To download external sources, run: DOWNLOAD_STOCK_SOURCES.cmd
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 0

:error_restore_pause
if defined LOCAL_NO_PAUSE set "STOCK_TOOLKIT_NO_PAUSE="
:error
echo.
echo [ERROR] Installation failed; review:
echo %LOG_FILE%
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 1
