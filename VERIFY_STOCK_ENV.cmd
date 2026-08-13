@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "FIXED_ROOT=D:\stock\GitHub"
set "HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
if not "%~1"=="" if /I not "%~1"=="/CHECK" if /I not "%~1"=="/PREFLIGHT" if /I not "%~1"=="/DRY-RUN" (
    echo [ERROR] Unknown option. Allowed: /CHECK, /PREFLIGHT or /DRY-RUN
    exit /b 2
)
if not exist "%HELPER%" (
    echo [ERROR] Fixed-root identity helper was not found: %HELPER%
    exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%

set "TARGET=%FIXED_ROOT%\scripts\compat\verify_stock_environment.cmd"
if not exist "%TARGET%" (
    echo [ERROR] Environment verification script was not found: %TARGET%
    pause
    exit /b 1
)

call "%TARGET%"
set "RC=%ERRORLEVEL%"
exit /b %RC%
