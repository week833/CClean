@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Verify stock toolkit environment

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "EXPECTED_ROOT=D:\stock\GitHub"
set "LEGACY_ROOT=D:\Downloads\stock"
set "LOG_FILE=%REPO_ROOT%\stock_environment_check.log"
set /a ERRORS=0

(
echo ============================================================
echo Stock toolkit environment check
echo Repository: %REPO_ROOT%
echo Expected path: %EXPECTED_ROOT%
echo Date: %DATE% %TIME%
echo ============================================================
) > "%LOG_FILE%"

call :check_file "INSTALL_D_STOCK_ENV.cmd"
call :check_file "INSTALL_D_STOCK_ENV_FULL.cmd"
call :check_file "STOCK_SETUP_MANAGER.cmd"
call :check_file "CONFIGURE_WINDOWS_ENV.cmd"
call :check_file "OPEN_STOCK_TERMINAL.cmd"
call :check_file "RUN_STOCK_PYTHON.cmd"
call :check_file "requirements.txt"
call :check_file "DOWNLOAD_STOCK_SOURCES.cmd"
call :check_file "DOWNLOAD_LEGACY_SOURCES.cmd"
call :check_file "REPAIR_STOCK_PATHS.cmd"
call :check_file "VERIFY_STOCK_ENV.cmd"
call :check_file "RECOVER_MOVED_STOCK_PROGRAMS.cmd"
call :check_file "scripts\setup\install_d_stock_env.ps1"
call :check_file "scripts\sources\clone_stock_analysis_repos.cmd"
call :check_file "scripts\sources\clone_legacy_compat_repos.cmd"
call :check_file "scripts\compat\repair_legacy_paths.cmd"

if /I "%REPO_ROOT%"=="%EXPECTED_ROOT%" (
    echo [OK] Repository is installed at %EXPECTED_ROOT%
    echo [OK] Repository path is correct >> "%LOG_FILE%"
) else (
    echo [WARN] Repository is running from %REPO_ROOT%
    echo [WARN] Expected path is %EXPECTED_ROOT%
    echo [WARN] Repository path differs >> "%LOG_FILE%"
)

if exist "%LEGACY_ROOT%" (
    echo [OK] Legacy compatibility path exists: %LEGACY_ROOT%
    echo [OK] Legacy path exists >> "%LOG_FILE%"
) else (
    echo [WARN] Legacy compatibility path is absent: %LEGACY_ROOT%
    echo [WARN] Legacy path is absent >> "%LOG_FILE%"
)

for /f "usebackq delims=" %%V in (`powershell.exe -NoLogo -NoProfile -Command "[Environment]::GetEnvironmentVariable('STOCK_VENV','User')"`) do set "USER_STOCK_VENV=%%V"
if not defined USER_STOCK_VENV set "USER_STOCK_VENV=%REPO_ROOT%\.venv"
set "VENV_PYTHON=!USER_STOCK_VENV!\Scripts\python.exe"

if exist "!VENV_PYTHON!" (
    echo [OK] Virtual environment Python exists: !VENV_PYTHON!
    echo [OK] Venv Python exists >> "%LOG_FILE%"
    "!VENV_PYTHON!" -c "import FinMind, twstock, pandas, numpy, yfinance, requests, matplotlib, openpyxl; print('CORE_IMPORT_OK')" >> "%LOG_FILE%" 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo [OK] Core package imports succeeded
    ) else (
        echo [FAIL] Core package imports failed
        set /a ERRORS+=1
    )
) else (
    echo [FAIL] Virtual environment Python was not found: !VENV_PYTHON!
    echo [FAIL] Venv Python missing >> "%LOG_FILE%"
    set /a ERRORS+=1
)

for /f "usebackq delims=" %%V in (`powershell.exe -NoLogo -NoProfile -Command "[Environment]::GetEnvironmentVariable('STOCK_HOME','User')"`) do set "USER_STOCK_HOME=%%V"
if /I "!USER_STOCK_HOME!"=="%REPO_ROOT%" (
    echo [OK] STOCK_HOME=%REPO_ROOT%
    echo [OK] STOCK_HOME is correct >> "%LOG_FILE%"
) else (
    echo [FAIL] STOCK_HOME=!USER_STOCK_HOME!
    echo [FAIL] STOCK_HOME differs >> "%LOG_FILE%"
    set /a ERRORS+=1
)

powershell.exe -NoLogo -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('Path','User'); if($p -and $p.ToLower().Contains('%REPO_ROOT:\=\\%\.venv\scripts'.ToLower())){exit 0}else{exit 1}" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    echo [OK] User PATH contains the virtual environment
) else (
    echo [WARN] User PATH may not contain the expected virtual environment
)

if exist "%REPO_ROOT%\external_repos" (
    echo [OK] external_repos exists
) else (
    echo [INFO] external_repos is not present yet
)

echo.
if !ERRORS! EQU 0 (
    echo Check completed: no blocking problems were found.
) else (
    echo Check completed: !ERRORS! blocking problem(s) were found.
)
echo Log file: %LOG_FILE%

if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b !ERRORS!

:check_file
if exist "%REPO_ROOT%\%~1" (
    echo [OK] %~1
    echo [OK] %~1 >> "%LOG_FILE%"
) else (
    echo [FAIL] Missing %~1
    echo [FAIL] Missing %~1 >> "%LOG_FILE%"
    set /a ERRORS+=1
)
exit /b 0
