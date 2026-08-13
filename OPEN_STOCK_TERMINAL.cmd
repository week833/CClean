@echo off
setlocal EnableExtensions

title Stock Toolkit Python Terminal
set "FIXED_ROOT=D:\stock\GitHub"
set "HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
if not exist "%HELPER%" (
    echo [ERROR] Fixed-root identity helper was not found: %HELPER%
    exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%

set "STOCK_HOME=%FIXED_ROOT%"
set "STOCK_VENV=%STOCK_HOME%\.venv"
set "STOCK_PYTHON=%STOCK_VENV%\Scripts\python.exe"
set "ACTIVATE=%STOCK_VENV%\Scripts\activate.bat"

if not exist "%ACTIVATE%" (
    echo [ERROR] Managed virtual environment was not found:
    echo %STOCK_VENV%
    echo Run STOCK_SETUP_MANAGER.cmd option 2 first.
    if not defined STOCK_TOOLKIT_NO_PAUSE pause
    exit /b 1
)

if not exist "%STOCK_PYTHON%" (
    echo [ERROR] Managed venv Python was not found:
    echo %STOCK_PYTHON%
    exit /b 1
)
"%STOCK_PYTHON%" --version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Managed venv Python could not start.
    exit /b 1
)

start "Stock Toolkit Python Environment" "%ComSpec%" /k "call ""%ACTIVATE%"" && cd /d ""%STOCK_HOME%"" && echo STOCK_HOME=%STOCK_HOME% && echo STOCK_PYTHON=%STOCK_PYTHON%"
exit /b 0
