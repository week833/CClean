@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Configure stock toolkit Windows environment

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "LEGACY_ROOT=D:\Downloads\stock"
set "VENV_DIR=%REPO_ROOT%\.venv"
set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "PS_SCRIPT=%TEMP%\configure_stock_env_%RANDOM%_%RANDOM%.ps1"

echo ============================================================
echo  Configure Windows environment safely
echo ============================================================
echo Repository: %REPO_ROOT%
echo.

if not exist "%REPO_ROOT%\requirements.txt" (
    echo [ERROR] This is not a valid stock repository: %REPO_ROOT%
    exit /b 1
)

if not exist "%VENV_PYTHON%" (
    echo [ERROR] Virtual environment was not found: %VENV_PYTHON%
    exit /b 1
)

rem Never create or replace D:\stock itself. Only create the old compatibility path when absent.
if not exist "D:\Downloads" mkdir "D:\Downloads" >nul 2>&1
if not exist "%LEGACY_ROOT%" (
    mklink /J "%LEGACY_ROOT%" "%REPO_ROOT%" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo [LINK] %LEGACY_ROOT% ^-^> %REPO_ROOT%
    ) else (
        echo [WARN] Legacy junction creation failed. Administrator rights may be required.
    )
) else (
    echo [KEEP] Existing legacy path was not modified: %LEGACY_ROOT%
)

echo [1/3] Setting user environment variables and PATH...
> "%PS_SCRIPT%" echo $ErrorActionPreference = 'Stop'
>> "%PS_SCRIPT%" echo $root = '%REPO_ROOT%'
>> "%PS_SCRIPT%" echo $venv = '%VENV_DIR%'
>> "%PS_SCRIPT%" echo $vars = @{
>> "%PS_SCRIPT%" echo   'STOCK_HOME' = $root
>> "%PS_SCRIPT%" echo   'STOCK_REPO' = $root
>> "%PS_SCRIPT%" echo   'STOCK_SHARED_ROOT' = 'D:\stock'
>> "%PS_SCRIPT%" echo   'STOCK_VENV' = $venv
>> "%PS_SCRIPT%" echo   'STOCK_PYTHON' = "$venv\Scripts\python.exe"
>> "%PS_SCRIPT%" echo   'STOCK_EXTERNAL_REPOS' = "$root\external_repos"
>> "%PS_SCRIPT%" echo   'PYTHONUTF8' = '1'
>> "%PS_SCRIPT%" echo   'PYTHONIOENCODING' = 'utf-8'
>> "%PS_SCRIPT%" echo }
>> "%PS_SCRIPT%" echo foreach ($name in $vars.Keys) { [Environment]::SetEnvironmentVariable($name, $vars[$name], 'User') }
>> "%PS_SCRIPT%" echo $add = @($root, "$venv\Scripts", "$root\scripts", "$root\scripts\setup", "$root\scripts\sources", "$root\scripts\compat")
>> "%PS_SCRIPT%" echo $existing = [Environment]::GetEnvironmentVariable('Path', 'User')
>> "%PS_SCRIPT%" echo $parts = New-Object 'System.Collections.Generic.List[string]'
>> "%PS_SCRIPT%" echo if ($existing) { foreach ($entry in $existing.Split(';')) { if ($entry -and $entry.Trim()) { $parts.Add($entry.Trim()) } } }
>> "%PS_SCRIPT%" echo foreach ($item in $add) {
>> "%PS_SCRIPT%" echo   $found = $false
>> "%PS_SCRIPT%" echo   foreach ($entry in $parts) { if ($entry.TrimEnd('\') -ieq $item.TrimEnd('\')) { $found = $true; break } }
>> "%PS_SCRIPT%" echo   if (-not $found) { $parts.Add($item) }
>> "%PS_SCRIPT%" echo }
>> "%PS_SCRIPT%" echo [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "PS_RC=%ERRORLEVEL%"
del "%PS_SCRIPT%" >nul 2>&1
if not "%PS_RC%"=="0" (
    echo [ERROR] User environment variables or PATH update failed.
    exit /b 1
)

echo [2/3] Configuring the current process...
set "STOCK_HOME=%REPO_ROOT%"
set "STOCK_REPO=%REPO_ROOT%"
set "STOCK_SHARED_ROOT=D:\stock"
set "STOCK_VENV=%VENV_DIR%"
set "STOCK_PYTHON=%VENV_PYTHON%"
set "STOCK_EXTERNAL_REPOS=%REPO_ROOT%\external_repos"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
set "PATH=%VENV_DIR%\Scripts;%REPO_ROOT%;%REPO_ROOT%\scripts;%PATH%"

echo [3/3] Verifying the virtual environment...
"%VENV_PYTHON%" -c "import sys, pandas, numpy, requests, yfinance; print(sys.executable); print('WINDOWS_ENV_OK')"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Virtual environment verification failed.
    exit /b 1
)

echo.
echo ============================================================
echo  Windows environment configuration completed
echo ============================================================
echo STOCK_HOME=%REPO_ROOT%
echo STOCK_PYTHON=%VENV_PYTHON%
echo Existing programs under D:\stock were not modified.
echo.
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 0
