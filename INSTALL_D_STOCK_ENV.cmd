@echo off
setlocal EnableExtensions

title D:\stock\GitHub Installer

set "CORE=%~dp0scripts\setup\install_d_stock_env.ps1"
set "ARGS="
set "EXIT_CODE=1"
set "NO_PAUSE=%STOCK_TOOLKIT_NO_PAUSE%"

for %%A in ("%~1" "%~2") do if not "%%~A"=="" if /I not "%%~A"=="/FULL" if /I not "%%~A"=="/PREFLIGHT" if /I not "%%~A"=="/DRY-RUN" if /I not "%%~A"=="/CHECK" if /I not "%%~A"=="/ELEVATED" goto :bad_argument

if /I "%~1"=="/FULL" set "ARGS=-Full"
if /I "%~1"=="/PREFLIGHT" set "ARGS=-Preflight -DryRun"
if /I "%~1"=="/DRY-RUN" set "ARGS=-Preflight -DryRun"
if /I "%~2"=="/FULL" set "ARGS=-Full"
if /I "%~2"=="/PREFLIGHT" set "ARGS=-Preflight -DryRun"
if /I "%~2"=="/DRY-RUN" set "ARGS=-Preflight -DryRun"
set "ELEVATED_ARGS=/ELEVATED"
if /I "%~1"=="/FULL" set "ELEVATED_ARGS=/ELEVATED /FULL"
if /I "%~1"=="/PREFLIGHT" set "ELEVATED_ARGS=/ELEVATED /PREFLIGHT"
if /I "%~1"=="/DRY-RUN" set "ELEVATED_ARGS=/ELEVATED /DRY-RUN"
if /I "%~2"=="/FULL" set "ELEVATED_ARGS=/ELEVATED /FULL"
if /I "%~2"=="/PREFLIGHT" set "ELEVATED_ARGS=/ELEVATED /PREFLIGHT"
if /I "%~2"=="/DRY-RUN" set "ELEVATED_ARGS=/ELEVATED /DRY-RUN"

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    if not defined NO_PAUSE pause
    exit /b 1
)

if /I "%~1"=="/CHECK" goto :check_local
if /I "%~2"=="/CHECK" goto :check_local

if not exist "%CORE%" (
    echo [ERROR] Local installer core is missing:
    echo %CORE%
    echo Remote scripts are not downloaded automatically.
    if not defined NO_PAUSE pause
    exit /b 1
)

rem Preflight is deliberately non-elevated and read-only. Formal installation
rem may request elevation because winget and the managed Python environment can
rem require it.
echo ============================================================
echo Starting stock toolkit operation
echo Install root: D:\stock\GitHub
if defined ARGS echo Arguments: %ARGS%
echo ============================================================

if /I "%~1"=="/PREFLIGHT" goto :run_core
if /I "%~1"=="/DRY-RUN" goto :run_core
if /I "%~1"=="/CHECK" goto :run_core
if /I "%~2"=="/PREFLIGHT" goto :run_core
if /I "%~2"=="/DRY-RUN" goto :run_core

powershell.exe -NoLogo -NoProfile -Command "if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo Requesting administrator privileges for formal installation...
    powershell.exe -NoLogo -NoProfile -Command "$p=Start-Process -FilePath '%~f0' -ArgumentList '%ELEVATED_ARGS%' -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
    if errorlevel 1 (
        echo [ERROR] Administrator elevation failed.
        if not defined NO_PAUSE pause
        exit /b 1
    )
    exit /b 0
)

:run_core
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CORE%" %ARGS%
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if "%EXIT_CODE%"=="0" (
    echo [OK] Operation completed.
) else (
    echo [ERROR] Operation stopped with exit code %EXIT_CODE%.
)
if not defined NO_PAUSE pause
exit /b %EXIT_CODE%

:check_local
if not exist "%CORE%" (
    echo [ERROR] Local installer core was not found:
    echo %CORE%
    exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile('%CORE%',[ref]$tokens,[ref]$errors) | Out-Null; if($errors.Count -gt 0){$errors | ForEach-Object { Write-Host $_.Message }; exit 1}; exit 0"
set "RC=%ERRORLEVEL%"
exit /b %RC%

:bad_argument
echo [ERROR] Unknown option. Allowed: /FULL, /PREFLIGHT, /DRY-RUN, /CHECK
exit /b 2
