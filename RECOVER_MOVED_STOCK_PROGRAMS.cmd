@echo off
setlocal EnableExtensions

title Recover programs moved by a previous installer

set "RECOVERY_PS1=%~dp0scripts\compat\recover_previous_stock_backups.ps1"

if not exist "%RECOVERY_PS1%" (
    echo [ERROR] Recovery script was not found:
    echo %RECOVERY_PS1%
    pause
    exit /b 1
)

echo ============================================================
echo  Recover programs moved by a previous installer
echo ============================================================
echo.
echo This tool only lists legacy D:\stock_backup_* folders.
echo Creating a second recovery copy is disabled by project policy.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RECOVERY_PS1%" -ListOnly
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
    echo [OK] Legacy backup listing completed; no files were copied.
) else (
    echo [ERROR] Backup listing failed with exit code %RC%.
)
pause
exit /b %RC%
