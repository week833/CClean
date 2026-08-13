@echo off
setlocal EnableExtensions

title Stock Toolkit Setup Manager
set "PACKAGE_ROOT=%~dp0"
set "FIXED_ROOT=D:\stock\GitHub"
set "HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
set "NO_PAUSE=1"
set "STOCK_TOOLKIT_NO_PAUSE=1"

:menu
cls
echo ============================================================
echo Stock Toolkit Setup Manager
echo Install root: %FIXED_ROOT%
echo Menu package: %PACKAGE_ROOT%
echo ============================================================
echo [1] Preflight / dry-run (read-only)
echo [2] Complete installation (environment + sources)
echo [3] Download core research sources
echo [4] Download all optional research sources
echo [5] Download legacy sources
echo [6] Repair legacy paths (explicit operation)
echo [7] Reconfigure user environment and PATH
echo [8] Verify installed environment
echo [9] Open terminal with the managed venv enabled
echo [Q] Exit
echo.
choice /C 123456789Q /N /M "Select: "
if errorlevel 10 goto :end
if errorlevel 9 goto :terminal
if errorlevel 8 goto :verify
if errorlevel 7 goto :configure
if errorlevel 6 goto :repair
if errorlevel 5 goto :legacy
if errorlevel 4 goto :sources_all
if errorlevel 3 goto :sources
if errorlevel 2 goto :full
if errorlevel 1 goto :preflight
goto :menu

:preflight
if exist "%FIXED_ROOT%" (
    call :require_fixed_root
    if errorlevel 1 goto :root_failed
    call "%FIXED_ROOT%\INSTALL_D_STOCK_ENV.cmd" /PREFLIGHT
) else (
    call "%PACKAGE_ROOT%INSTALL_D_STOCK_ENV.cmd" /PREFLIGHT
)
set "RC=%ERRORLEVEL%"
echo Preflight exit code: %RC%
pause
goto :menu

:full
if exist "%FIXED_ROOT%" (
    call :require_fixed_root
    if errorlevel 1 goto :root_failed
    call "%FIXED_ROOT%\INSTALL_D_STOCK_ENV_FULL.cmd"
) else (
    call "%PACKAGE_ROOT%INSTALL_D_STOCK_ENV_FULL.cmd"
)
set "RC=%ERRORLEVEL%"
echo Full installation exit code: %RC%
pause
goto :menu

:sources
call :require_fixed_root
if errorlevel 1 goto :root_failed
call "%FIXED_ROOT%\DOWNLOAD_STOCK_SOURCES.cmd"
set "RC=%ERRORLEVEL%"
echo Core source download exit code: %RC%
pause
goto :menu

:sources_all
call :require_fixed_root
if errorlevel 1 goto :root_failed
call "%FIXED_ROOT%\DOWNLOAD_STOCK_SOURCES.cmd" --all
set "RC=%ERRORLEVEL%"
echo Optional source download exit code: %RC%
pause
goto :menu

:legacy
call :require_fixed_root
if errorlevel 1 goto :root_failed
call "%FIXED_ROOT%\DOWNLOAD_LEGACY_SOURCES.cmd"
set "RC=%ERRORLEVEL%"
echo Legacy source exit code: %RC%
pause
goto :menu

:repair
call :require_fixed_root
if errorlevel 1 goto :root_failed
call "%FIXED_ROOT%\REPAIR_STOCK_PATHS.cmd" --check
set "RC=%ERRORLEVEL%"
if errorlevel 1 goto :repair_check_failed
echo Legacy path check passed; no junctions were created.
echo Choose Y only if you explicitly want to apply the checked junction changes.
choice /C YN /N /M "Apply legacy path changes now? [Y/N]: "
if errorlevel 2 goto :repair_declined
call "%FIXED_ROOT%\REPAIR_STOCK_PATHS.cmd" --apply --confirm
set "RC=%ERRORLEVEL%"
echo Legacy path apply exit code: %RC%
pause
goto :menu

:repair_check_failed
echo [WARN] Legacy path check failed (exit code %RC%); no junctions were created or repaired.
pause
goto :menu

:repair_declined
echo Legacy path apply declined; no junctions were created or changed.
pause
goto :menu

:configure
call :require_fixed_root
if errorlevel 1 goto :root_failed
call "%FIXED_ROOT%\CONFIGURE_WINDOWS_ENV.cmd"
set "RC=%ERRORLEVEL%"
echo Environment configuration exit code: %RC%
pause
goto :menu

:verify
call :require_fixed_root
if errorlevel 1 goto :root_failed
call "%FIXED_ROOT%\VERIFY_STOCK_ENV.cmd"
set "RC=%ERRORLEVEL%"
echo Verification exit code: %RC%
pause
goto :menu

:terminal
call :require_fixed_root
if errorlevel 1 goto :root_failed
call "%FIXED_ROOT%\OPEN_STOCK_TERMINAL.cmd"
set "RC=%ERRORLEVEL%"
echo Terminal launcher exit code: %RC%
pause
goto :menu

:require_fixed_root
if not exist "%HELPER%" (
    echo [ERROR] Fixed-root identity helper was not found: %HELPER%
    exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
exit /b 0

:root_failed
set "RC=%ERRORLEVEL%"
echo [ERROR] Fixed-root identity check failed; no local copy was used. Exit code: %RC%
pause
goto :menu

:end
exit /b 0
