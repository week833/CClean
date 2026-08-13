@echo off
setlocal EnableExtensions

title Configure stock toolkit Windows environment

set "CORE=%~dp0install_d_stock_env.ps1"
set "ARGS=-ConfigureOnly"
set "NO_PAUSE=%STOCK_TOOLKIT_NO_PAUSE%"

if /I "%~1"=="/PREFLIGHT" set "ARGS=-ConfigureOnly -Preflight -DryRun"
if /I "%~1"=="/DRY-RUN" set "ARGS=-ConfigureOnly -Preflight -DryRun"
if /I "%~1"=="/CHECK" set "ARGS=-ConfigureOnly -Preflight -DryRun"

if not exist "%CORE%" (
    echo [ERROR] Installer core was not found:
    echo %CORE%
    if not defined NO_PAUSE pause
    exit /b 1
)

echo ============================================================
echo Configure stock toolkit user environment
echo Install root: D:\stock\GitHub
if defined ARGS echo Arguments: %ARGS%
echo ============================================================
echo This action never creates a legacy junction or repairs paths.
echo Dry-run mode does not write user PATH, registry or files.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CORE%" %ARGS%
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
    echo [OK] Environment configuration completed.
) else (
    echo [ERROR] Environment configuration stopped with exit code %RC%.
)
if not defined NO_PAUSE pause
exit /b %RC%
