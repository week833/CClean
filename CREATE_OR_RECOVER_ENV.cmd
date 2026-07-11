@echo off
setlocal EnableExtensions

title Create or recover D:\stock\GitHub\.env

set "LOCAL_PS1=%~dp0scripts\setup\create_or_recover_env.ps1"
set "ADJACENT_PS1=%~dp0create_or_recover_env.ps1"
set "TEMP_PS1=%TEMP%\create_or_recover_env_%RANDOM%_%RANDOM%.ps1"
set "PS_SCRIPT="
set "RC=1"

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    pause
    exit /b 1
)

if exist "%LOCAL_PS1%" set "PS_SCRIPT=%LOCAL_PS1%"
if not defined PS_SCRIPT if exist "%ADJACENT_PS1%" set "PS_SCRIPT=%ADJACENT_PS1%"

if not defined PS_SCRIPT (
    echo Downloading the latest safe .env creator...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/week833/stock/main/scripts/setup/create_or_recover_env.ps1' -OutFile '%TEMP_PS1%'"
    if errorlevel 1 goto :download_error
    set "PS_SCRIPT=%TEMP_PS1%"
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile('%PS_SCRIPT%',[ref]$tokens,[ref]$errors) ^| Out-Null; if($errors.Count -gt 0){$errors ^| ForEach-Object { Write-Host $_.Message }; exit 1}; exit 0"
if errorlevel 1 goto :parse_error

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "RC=%ERRORLEVEL%"

if exist "%TEMP_PS1%" del /q "%TEMP_PS1%" >nul 2>nul

echo.
if "%RC%"=="0" (
    echo [OK] .env operation completed.
) else (
    echo [ERROR] .env operation failed with exit code %RC%.
)
echo.
pause
exit /b %RC%

:download_error
echo [ERROR] Unable to download the .env creator.
echo Keep create_or_recover_env.ps1 beside this CMD file or check GitHub access.
pause
exit /b 1

:parse_error
echo [ERROR] The PowerShell .env creator failed syntax validation.
if exist "%TEMP_PS1%" del /q "%TEMP_PS1%" >nul 2>nul
pause
exit /b 1
