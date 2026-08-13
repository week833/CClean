@echo off
setlocal EnableExtensions
set "ERRORLEVEL="

set "FIXED_ROOT=D:\stock\GitHub"
set "MANAGER=%FIXED_ROOT%\scripts\sources\source_manager.ps1"

if "%~1"=="" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_core
if /I "%~1"=="--all" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_all
if /I "%~1"=="--check" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_check
if /I "%~1"=="--check" if /I "%~2"=="--all" if "%~3"=="" if "%~4"=="" goto :stock_check_all
if /I "%~1"=="--verify" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_verify
if /I "%~1"=="--verify" if /I "%~2"=="--all" if "%~3"=="" if "%~4"=="" goto :stock_verify_all
goto :bad_args

:stock_core
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%"
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_all
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -All
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_check
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -Check
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_check_all
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -All -Check
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_verify
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -Verify
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_verify_all
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -All -Verify
set "RC=%ERRORLEVEL%"
exit /b %RC%

:bad_args
echo [ERROR] Unknown option. Use no option, --all, --check [--all], or --verify [--all].
exit /b 2
