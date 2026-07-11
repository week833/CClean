@echo off
setlocal EnableExtensions

title D:\stock Full Installer

set "LOCAL_PS1=%~dp0scripts\setup\install_d_stock_env.ps1"
set "ADJACENT_PS1=%~dp0install_d_stock_env.ps1"
set "TEMP_PS1=%TEMP%\install_d_stock_env_full_%RANDOM%_%RANDOM%.ps1"
set "PS_SCRIPT="
set "EXIT_CODE=1"

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    echo.
    pause
    exit /b 1
)

if /I "%~1"=="/CHECK" goto :check_local

powershell.exe -NoLogo -NoProfile -Command "if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo Requesting administrator privileges...
    powershell.exe -NoLogo -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '/ELEVATED' -Verb RunAs"
    if errorlevel 1 (
        echo [ERROR] Administrator elevation failed.
        echo Right-click this file and select Run as administrator.
        echo.
        pause
    )
    exit /b
)

echo ============================================================
echo D:\stock Full Installer
echo ============================================================
echo This mode installs the core environment and downloads all
echo primary, large, and legacy research repositories.
echo.

echo Downloading the latest installer core...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/week833/stock/main/scripts/setup/install_d_stock_env.ps1' -OutFile '%TEMP_PS1%'"
if not errorlevel 1 set "PS_SCRIPT=%TEMP_PS1%"

if not defined PS_SCRIPT if exist "%LOCAL_PS1%" set "PS_SCRIPT=%LOCAL_PS1%"
if not defined PS_SCRIPT if exist "%ADJACENT_PS1%" set "PS_SCRIPT=%ADJACENT_PS1%"

if not defined PS_SCRIPT goto :download_error

call :parse_core
if errorlevel 1 goto :parse_error

echo Starting full installation...
echo Core script: %PS_SCRIPT%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Full
set "EXIT_CODE=%ERRORLEVEL%"

if exist "%TEMP_PS1%" del /q "%TEMP_PS1%" >nul 2>nul

echo.
if "%EXIT_CODE%"=="0" (
    echo [OK] Full installation and all repository downloads completed.
    echo Install root: D:\stock
    echo Python: D:\stock\.venv\Scripts\python.exe
    echo Repositories: D:\stock\external_repos
) else (
    echo [ERROR] Full installation failed with exit code %EXIT_CODE%.
    echo Log file: %TEMP%\install_d_stock_env.log
)
echo.
echo Press any key to close...
pause >nul
exit /b %EXIT_CODE%

:check_local
set "PS_SCRIPT=%LOCAL_PS1%"
if not exist "%PS_SCRIPT%" (
    echo [ERROR] Local installer core was not found:
    echo %PS_SCRIPT%
    exit /b 1
)
call :parse_core
exit /b %ERRORLEVEL%

:parse_core
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile('%PS_SCRIPT%',[ref]$tokens,[ref]$errors) | Out-Null; if($errors.Count -gt 0){$errors | ForEach-Object { Write-Host $_.Message }; exit 1}; exit 0"
exit /b %ERRORLEVEL%

:download_error
echo.
echo [ERROR] The installer core could not be downloaded or found locally.
echo Check access to raw.githubusercontent.com.
echo.
pause
exit /b 1

:parse_error
echo.
echo [ERROR] The PowerShell installer core failed syntax validation.
echo Parser output is shown above.
if exist "%TEMP_PS1%" del /q "%TEMP_PS1%" >nul 2>nul
echo.
pause
exit /b 1
