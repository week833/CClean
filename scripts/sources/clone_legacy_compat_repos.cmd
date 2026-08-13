@echo off
setlocal EnableExtensions
set "ERRORLEVEL="

set "FIXED_ROOT=D:\stock\GitHub"
set "MANAGER=%FIXED_ROOT%\scripts\sources\source_manager.ps1"

if "%~1"=="" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :legacy_update
if /I "%~1"=="--check" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :legacy_check
if /I "%~1"=="--verify" if "%~2"=="" if "%~3"=="" if "%~4"=="" goto :legacy_verify
goto :bad_args

:legacy_update
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -Legacy
set "RC=%ERRORLEVEL%"
exit /b %RC%

:legacy_check
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -Legacy -Check
set "RC=%ERRORLEVEL%"
exit /b %RC%

:legacy_verify
if not exist "%MANAGER%" exit /b 2
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MANAGER%" -Root "%FIXED_ROOT%" -Legacy -Verify
set "RC=%ERRORLEVEL%"
exit /b %RC%

:bad_args
echo [ERROR] Unknown option. Use no option, --check, or --verify.
exit /b 2
