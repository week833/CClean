@echo off
setlocal EnableExtensions

title Create or recover D:\stock\GitHub\.env

set "LOCAL_PS1=%~dp0scripts\setup\create_or_recover_env.ps1"
set "PS_SCRIPT="
set "RC=1"

if not "%~1"=="" (
    echo [ERROR] This tool accepts no command-line arguments.
    exit /b 2
)

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    pause
    exit /b 1
)

if exist "%LOCAL_PS1%" set "PS_SCRIPT=%LOCAL_PS1%"

if not defined PS_SCRIPT (
    echo [ERROR] Local create_or_recover_env.ps1 is missing:
    echo %LOCAL_PS1%
    echo Remote scripts are not downloaded automatically.
    exit /b 2
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile('%PS_SCRIPT%',[ref]$tokens,[ref]$errors) ^| Out-Null; if($errors.Count -gt 0){$errors ^| ForEach-Object { Write-Host $_.Message }; exit 1}; exit 0"
if errorlevel 1 goto :parse_error

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo [OK] .env operation completed.
) else (
    echo [ERROR] .env operation failed with exit code %RC%.
)
echo.
pause
exit /b %RC%

:parse_error
echo [ERROR] The PowerShell .env creator failed syntax validation.
pause
exit /b 1
