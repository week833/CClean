@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "FIXED_ROOT=D:\stock\GitHub"
set "HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
set "ARGS="
if "%~1"=="" goto :bad_args
if /I "%~1"=="--check" if "%~2"=="" set "ARGS=--check"&goto :args_ok
if /I "%~1"=="--apply" if /I "%~2"=="--confirm" if "%~3"=="" set "ARGS=--apply --confirm"&goto :args_ok
:bad_args
echo [ERROR] Unknown option. Allowed: --check or --apply --confirm
exit /b 2
:args_ok
if not exist "%HELPER%" (
    echo [ERROR] Fixed-root identity helper was not found: %HELPER%
    exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%

set "TARGET=%FIXED_ROOT%\scripts\compat\repair_legacy_paths.cmd"
if not exist "%TARGET%" (
    echo [ERROR] Path repair script was not found: %TARGET%
    pause
    exit /b 1
)

call "%TARGET%" %ARGS%
set "RC=%ERRORLEVEL%"
exit /b %RC%
