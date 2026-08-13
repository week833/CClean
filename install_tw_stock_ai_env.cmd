@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem Legacy compatibility launcher; preserve the old filename and delegate.
set "FIXED_ROOT=D:\stock\GitHub"
set "HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
if not exist "%HELPER%" (
    echo [ERROR] Fixed-root identity helper was not found: %HELPER%
    exit /b 2
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%

set "TARGET=%FIXED_ROOT%\scripts\setup\install_tw_stock_ai_env.cmd"

if not exist "%TARGET%" (
    echo [ERROR] New environment installer was not found:
    echo %TARGET%
    pause
    exit /b 1
)

set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
if "%RC%"=="0" (
    echo Environment installation / repair completed.
) else (
    echo [ERROR] Environment installation / repair failed, exit code: %RC%
)
pause
exit /b %RC%
