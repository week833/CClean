@echo off
setlocal EnableExtensions
set "ERRORLEVEL="

set "FIXED_ROOT=D:\stock\GitHub"
set "HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
set "TARGET=%FIXED_ROOT%\scripts\sources\clone_stock_analysis_repos.cmd"

if "%~1"=="" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_core
if /I "%~1"=="--all" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_all
if /I "%~1"=="--check" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_check
if /I "%~1"=="--check" if /I "%~2"=="--all" if "%~3"=="" if "%~4"=="" goto :stock_check_all
if /I "%~1"=="--verify" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :stock_verify
if /I "%~1"=="--verify" if /I "%~2"=="--all" if "%~3"=="" if "%~4"=="" goto :stock_verify_all
goto :bad_args

:stock_core
call :preflight
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
call "%TARGET%"
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_all
call :preflight
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
call "%TARGET%" --all
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_check
call :preflight
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
call "%TARGET%" --check
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_check_all
call :preflight
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
call "%TARGET%" --check --all
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_verify
call :preflight
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
call "%TARGET%" --verify
set "RC=%ERRORLEVEL%"
exit /b %RC%

:stock_verify_all
call :preflight
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
call "%TARGET%" --verify --all
set "RC=%ERRORLEVEL%"
exit /b %RC%

:preflight
if not exist "%HELPER%" exit /b 2
if not exist "%TARGET%" exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
set "STOCK_TOOLKIT_NO_PAUSE=1"
exit /b 0

:bad_args
echo [ERROR] Unsupported source option combination.
exit /b 2
