@echo off
setlocal EnableExtensions

set "STOCK_HOME=%STOCK_HOME%"
if not defined STOCK_HOME set "STOCK_HOME=D:\stock\GitHub"
set "STOCK_PYTHON=%STOCK_PYTHON%"
if not defined STOCK_PYTHON set "STOCK_PYTHON=%STOCK_HOME%\.venv\Scripts\python.exe"

if not exist "%STOCK_PYTHON%" (
    echo [ERROR] Python executable was not found:
    echo %STOCK_PYTHON%
    echo Run INSTALL_D_STOCK_ENV_FULL.cmd first.
    pause
    exit /b 1
)

cd /d "%STOCK_HOME%"
"%STOCK_PYTHON%" %*
exit /b %ERRORLEVEL%
