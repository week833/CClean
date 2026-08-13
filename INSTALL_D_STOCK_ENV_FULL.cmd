@echo off
setlocal EnableExtensions

title D:\stock\GitHub Full Installer

set "FIXED_ROOT=D:\stock\GitHub"
set "FIXED_HELPER=%FIXED_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
set "LOCAL_CORE=%~dp0scripts\setup\install_d_stock_env.ps1"
set "CORE=%FIXED_ROOT%\scripts\setup\install_d_stock_env.ps1"
set "BOOTSTRAP=0"
set "PREFLIGHT=0"
set "CHECK_ONLY=0"
set "ELEVATED=0"
set "ARGS=-Full"
set "EXIT_CODE=1"
set "NO_PAUSE=%STOCK_TOOLKIT_NO_PAUSE%"
set "ORIGINAL_NO_PAUSE=%STOCK_TOOLKIT_NO_PAUSE%"

rem Keep argument parsing fail-closed.  The values used below are fixed
rem switches; no raw argument is ever placed in a delayed-expansion block.
if not "%~3"=="" goto :bad_argument
for %%A in ("%~1" "%~2") do if not "%%~A"=="" if /I not "%%~A"=="/PREFLIGHT" if /I not "%%~A"=="/DRY-RUN" if /I not "%%~A"=="/CHECK" if /I not "%%~A"=="/ELEVATED" goto :bad_argument

if /I "%~1"=="/PREFLIGHT" set "PREFLIGHT=1"
if /I "%~2"=="/PREFLIGHT" set "PREFLIGHT=1"
if /I "%~1"=="/DRY-RUN" set "PREFLIGHT=1"
if /I "%~2"=="/DRY-RUN" set "PREFLIGHT=1"
if /I "%~1"=="/CHECK" set "CHECK_ONLY=1"
if /I "%~2"=="/CHECK" set "CHECK_ONLY=1"
if /I "%~1"=="/ELEVATED" set "ELEVATED=1"
if /I "%~2"=="/ELEVATED" set "ELEVATED=1"
if "%PREFLIGHT%"=="1" set "ARGS=-Full -Preflight -DryRun"
set "ELEVATED_ARGS=/ELEVATED"
if "%PREFLIGHT%"=="1" set "ELEVATED_ARGS=/ELEVATED /PREFLIGHT"

where powershell.exe >nul 2>nul
if errorlevel 1 goto :powershell_missing

if "%CHECK_ONLY%"=="1" goto :check_fixed_root
call :resolve_core
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%

if "%PREFLIGHT%"=="1" goto :run_core
if "%ELEVATED%"=="1" goto :run_core

powershell.exe -NoLogo -NoProfile -Command "if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }"
if errorlevel 1 goto :request_elevation
goto :run_core

:request_elevation
echo Requesting administrator privileges for full installation...
powershell.exe -NoLogo -NoProfile -Command "$p=Start-Process -FilePath '%~f0' -ArgumentList '%ELEVATED_ARGS%' -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto :elevation_failed
exit /b 0

:run_core
echo ============================================================
echo Starting full stock toolkit operation
echo Install root: D:\stock\GitHub
echo Sources: D:\stock\GitHub\repos
echo ============================================================
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CORE%" %ARGS%
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" goto :report
if "%PREFLIGHT%"=="1" goto :report

if "%BOOTSTRAP%"=="1" goto :verify_bootstrap
goto :download_primary

:verify_bootstrap
if exist "%FIXED_HELPER%" goto :verify_bootstrap_run
echo [ERROR] Bootstrap completed but fixed-root identity helper is missing:
echo %FIXED_HELPER%
set "EXIT_CODE=2"
goto :report

:verify_bootstrap_run
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FIXED_HELPER%"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" goto :report

:download_primary
rem Full mode defaults to the three core primary sources, then the two unique
rem legacy compatibility identities, followed by a read-only verification.
set "STOCK_TOOLKIT_NO_PAUSE=1"
echo.
echo [FULL 1/3] Downloading core research sources...
call "%FIXED_ROOT%\scripts\sources\clone_stock_analysis_repos.cmd"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" goto :source_error

echo [FULL 2/3] Downloading legacy sources...
if exist "%FIXED_ROOT%\scripts\sources\clone_legacy_compat_repos.cmd" goto :download_legacy_call
echo [ERROR] Legacy source script was not found:
echo %FIXED_ROOT%\scripts\sources\clone_legacy_compat_repos.cmd
set "EXIT_CODE=2"
goto :source_error

:download_legacy_call
call "%FIXED_ROOT%\scripts\sources\clone_legacy_compat_repos.cmd"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" goto :source_error

:download_legacy_done
echo [FULL 3/3] Verifying environment...
call "%FIXED_ROOT%\scripts\compat\verify_stock_environment.cmd"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" goto :source_error
set "STOCK_TOOLKIT_NO_PAUSE=%ORIGINAL_NO_PAUSE%"
goto :report

:source_error
set "STOCK_TOOLKIT_NO_PAUSE=%ORIGINAL_NO_PAUSE%"
echo [ERROR] Full operation stopped during source download or verification.
goto :report

:report
echo.
if "%EXIT_CODE%"=="0" goto :report_ok
echo [ERROR] Full operation stopped with exit code %EXIT_CODE%.
goto :report_pause

:report_ok
echo [OK] Full operation completed.

:report_pause
if not defined NO_PAUSE pause
exit /b %EXIT_CODE%

:resolve_core
if exist "%FIXED_ROOT%" goto :resolve_existing_root
if exist "%LOCAL_CORE%" goto :resolve_bootstrap
echo [ERROR] Fixed root is missing and the bootstrap installer core was not found:
echo %LOCAL_CORE%
exit /b 2

:resolve_bootstrap
set "CORE=%LOCAL_CORE%"
set "BOOTSTRAP=1"
exit /b 0

:resolve_existing_root
if exist "%FIXED_HELPER%" goto :resolve_identity
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p='D:\stock\GitHub'; $i=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; if(-not $i -or -not $i.PSIsContainer -or (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){exit 2}; if(@(Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop).Count -ne 0){exit 1}; exit 0"
set "RC=%ERRORLEVEL%"
if "%RC%"=="2" goto :resolve_nonphysical
if not "%RC%"=="0" goto :resolve_nonempty
goto :resolve_bootstrap

:resolve_identity
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FIXED_HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
exit /b 0

:resolve_nonphysical
echo [ERROR] Fixed root is not an ordinary physical directory.
exit /b 2

:resolve_nonempty
echo [ERROR] Fixed root exists without the identity helper and is not completely empty.
echo No files were moved or deleted: %FIXED_ROOT%
exit /b 2

:check_fixed_root
if not exist "%FIXED_HELPER%" goto :check_helper_missing
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FIXED_HELPER%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
if exist "%CORE%" goto :check_core_syntax
echo [ERROR] Fixed-root installer core was not found:
echo %CORE%
exit /b 2

:check_core_syntax
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile('%CORE%',[ref]$tokens,[ref]$errors) | ForEach-Object { }; if($errors.Count -gt 0){$errors | ForEach-Object { Write-Host $_.Message }; exit 1}; exit 0"
set "RC=%ERRORLEVEL%"
exit /b %RC%

:check_helper_missing
echo [ERROR] Fixed-root identity helper was not found: %FIXED_HELPER%
exit /b 2

:powershell_missing
echo [ERROR] Windows PowerShell was not found.
if not defined NO_PAUSE pause
exit /b 1

:elevation_failed
echo [ERROR] Administrator elevation failed.
if not defined NO_PAUSE pause
exit /b %RC%

:bad_argument
echo [ERROR] Unknown option. Allowed: /PREFLIGHT, /DRY-RUN, /CHECK
if not defined NO_PAUSE pause
exit /b 2
