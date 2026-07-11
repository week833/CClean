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
echo This tool copies data from D:\stock_backup_* folders into:
echo D:\stock\Recovered_from_previous_installer_YYYYMMDD_HHMMSS
echo.
echo It does not delete backup folders and does not overwrite existing
echo programs directly under D:\stock.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RECOVERY_PS1%" -ListOnly
echo.
choice /C YN /N /M "Copy the listed backup folders into a safe recovery folder? [Y/N]: "
if errorlevel 2 exit /b 0

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RECOVERY_PS1%"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
    echo [OK] Recovery copy completed.
) else (
    echo [ERROR] Recovery failed with exit code %RC%.
)
pause
exit /b %RC%
