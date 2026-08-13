@echo off
setlocal EnableExtensions

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
set "STOCK_PYTHON=%FIXED_ROOT%\.venv\Scripts\python.exe"
set "PY_ARGS="
if "%~1"=="" set "PY_ARGS="
if /I "%~1"=="/VERSION" if "%~2"=="" set "PY_ARGS=--version"
if not "%~1"=="" if not defined PY_ARGS (
    echo [ERROR] Unknown option. Allowed: no arguments or /VERSION
    exit /b 2
)

if not exist "%STOCK_PYTHON%" (
    echo [ERROR] Python executable was not found:
    echo %STOCK_PYTHON%
    echo Run INSTALL_D_STOCK_ENV_FULL.cmd first.
    pause
    exit /b 1
)

"%STOCK_PYTHON%" --version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Fixed-root Python executable could not start.
    exit /b 1
)

cd /d "%FIXED_ROOT%" || exit /b 1
"%STOCK_PYTHON%" %PY_ARGS%
set "RC=%ERRORLEVEL%"
exit /b %RC%
