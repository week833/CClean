@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "FIXED_ROOT=D:\stock\GitHub"
set "HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
set "ARGS="
if "%~1"=="" goto :args_ok
if /I "%~1"=="/PREFLIGHT" if "%~2"=="" set "ARGS=/PREFLIGHT"&goto :args_ok
if /I "%~1"=="/DRY-RUN" if "%~2"=="" set "ARGS=/DRY-RUN"&goto :args_ok
if /I "%~1"=="/CHECK" if "%~2"=="" set "ARGS=/CHECK"&goto :args_ok
echo [ERROR] Unknown option. Allowed: /PREFLIGHT, /DRY-RUN, /CHECK
exit /b 2
:args_ok
if not exist "%HELPER%" (
    echo [ERROR] Fixed-root identity helper was not found: %HELPER%
    exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%

set "TARGET=%FIXED_ROOT%\scripts\setup\configure_windows_environment.cmd"
if not exist "%TARGET%" (
    echo [ERROR] Target was not found: %TARGET%
    echo Run the fixed-root installer first.
    pause
    exit /b 1
)

call "%TARGET%" %ARGS%
set "RC=%ERRORLEVEL%"
exit /b %RC%
