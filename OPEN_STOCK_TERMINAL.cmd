@echo off
setlocal EnableExtensions

set "STOCK_HOME=%STOCK_HOME%"
if not defined STOCK_HOME set "STOCK_HOME=D:\stock\GitHub"
set "STOCK_VENV=%STOCK_VENV%"
if not defined STOCK_VENV set "STOCK_VENV=%STOCK_HOME%\.venv"
set "ACTIVATE=%STOCK_VENV%\Scripts\activate.bat"

if not exist "%ACTIVATE%" (
    echo [ERROR] Virtual environment was not found:
    echo %ACTIVATE%
    echo Run INSTALL_D_STOCK_ENV_FULL.cmd first.
    pause
    exit /b 1
)

start "Stock Toolkit Python Environment" cmd /k "cd /d %STOCK_HOME% && call %ACTIVATE% && echo STOCK_HOME=%STOCK_HOME%"
exit /b 0
