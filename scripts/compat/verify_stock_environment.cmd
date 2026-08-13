@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Verify stock toolkit environment

rem Read-only verifier.  It never installs, downloads, repairs, clones, pulls,
rem writes environment variables, creates links, or changes a repository.
set "EXPECTED_ROOT=D:\stock\GitHub"
set "VERIFY_ROOT=%EXPECTED_ROOT%"
set "TEST_MODE="
if /I "%STOCK_VERIFY_TEST_MODE%"=="1" if defined STOCK_VERIFY_ROOT (
    set "VERIFY_ROOT=%STOCK_VERIFY_ROOT%"
    set "TEST_MODE=1"
)

set "VENV_DIR=%VERIFY_ROOT%\.venv"
set "VENV_SCRIPTS=%VENV_DIR%\Scripts"
set "VENV_PYTHON=%VENV_SCRIPTS%\python.exe"
if /I "%STOCK_VERIFY_TEST_MODE%"=="1" if defined STOCK_VERIFY_VENV_PYTHON set "VENV_PYTHON=%STOCK_VERIFY_VENV_PYTHON%"
set "SOURCE_MANIFEST=%VERIFY_ROOT%\scripts\sources\source_manifest_v1.json"
set "LEGACY_MANIFEST=%SOURCE_MANIFEST%"
set "FIXED_ROOT_HELPER=%VERIFY_ROOT%\scripts\setup\assert_fixed_install_root.ps1"
set "SOURCE_MANAGER=%VERIFY_ROOT%\scripts\sources\source_manager.ps1"
set "STOCK_SOURCES_WRAPPER=%VERIFY_ROOT%\DOWNLOAD_STOCK_SOURCES.cmd"
set "LEGACY_SOURCES_WRAPPER=%VERIFY_ROOT%\DOWNLOAD_LEGACY_SOURCES.cmd"
if /I "%STOCK_VERIFY_TEST_MODE%"=="1" if defined STOCK_VERIFY_STOCK_WRAPPER set "STOCK_SOURCES_WRAPPER=%STOCK_VERIFY_STOCK_WRAPPER%"
if /I "%STOCK_VERIFY_TEST_MODE%"=="1" if defined STOCK_VERIFY_LEGACY_WRAPPER set "LEGACY_SOURCES_WRAPPER=%STOCK_VERIFY_LEGACY_WRAPPER%"
set "PACKAGE_HELPER=%VERIFY_ROOT%\scripts\compat\verify_python_packages.py"
set "REQUIREMENTS_FILE=%VERIFY_ROOT%\requirements.txt"
set "EXPECTED_ORIGIN=https://github.com/week833/stock.git"
set /a ERRORS=0
set /a WARNINGS=0
set /a PRIMARY_COUNT=0
set /a PRIMARY_DEFAULT_COUNT=0
set /a MANIFEST_LEGACY_COUNT=0
set /a LEGACY_ALIAS_COUNT=0
set /a LEGACY_COUNT=0
set /a PRIMARY_MISSING=0
set /a LEGACY_MISSING=0
set /a INVALID_SOURCES=0
set /a JUNCTION_COUNT=0
set /a EXPECTED_JUNCTIONS=57
if defined STOCK_VERIFY_EXPECTED_JUNCTIONS set /a EXPECTED_JUNCTIONS=%STOCK_VERIFY_EXPECTED_JUNCTIONS%
set "GIT_EXE="
set "VERIFY_ORIGIN="
set "VERIFY_STATUS="
set "CRITICAL_FILES_OK=1"

echo ============================================================
echo Stock toolkit environment verification - read-only
echo ============================================================
echo Fixed install root: %EXPECTED_ROOT%
if defined TEST_MODE echo Test fixture root: %VERIFY_ROOT%
echo.

rem Every file that will be executed or parsed below must be a regular file
rem inside VERIFY_ROOT, with no reparse-point ancestor.  Fail closed before
rem invoking Python, source wrappers, or reading the source manifest.
call :check_critical_files
if "!CRITICAL_FILES_OK!"=="0" goto :verification_summary

if not defined TEST_MODE if /I not "%VERIFY_ROOT%"=="%EXPECTED_ROOT%" (
    echo [FAIL] Verifier root is not the fixed install root: %VERIFY_ROOT%
    set /a ERRORS+=1
)
if defined TEST_MODE echo [INFO] Test-only root override is active; production mode remains fixed.

call :check_root_layout
call :find_git
call :check_repository
call :check_user_environment
call :check_user_path
call :check_venv
call :check_source_wrappers
call :check_primary_sources_v1
call :check_legacy_sources_v1
call :check_junctions

:verification_summary
echo.
echo ============================================================
echo Verification summary
echo ============================================================
echo primary_manifest=!PRIMARY_COUNT! (default !PRIMARY_DEFAULT_COUNT!, missing !PRIMARY_MISSING!)
echo legacy_manifest=!LEGACY_COUNT! (missing !LEGACY_MISSING!)
echo invalid_sources=!INVALID_SOURCES! junctions=!JUNCTION_COUNT! reference=!EXPECTED_JUNCTIONS!
echo warnings=!WARNINGS! errors=!ERRORS!
echo [INFO] AI/Agent research sources are optional and are not required for formal verification.
if !ERRORS! GTR 0 (
    echo [FAIL] Blocking verification problems were found.
) else (
    echo [OK] Verification completed; warnings are non-blocking.
)
echo ============================================================

if not defined STOCK_TOOLKIT_NO_PAUSE pause
if !ERRORS! GTR 0 exit /b 1
exit /b 0

:check_critical_files
set "CRITICAL_FILES_OK=1"
call :check_critical_file "fixed-root helper" "%FIXED_ROOT_HELPER%" file
call :check_critical_file "source manager" "%SOURCE_MANAGER%" file
call :check_critical_file "Python package verifier" "%PACKAGE_HELPER%" file
call :check_critical_file "requirements file" "%REQUIREMENTS_FILE%" file
call :check_critical_file "venv Python" "%VENV_PYTHON%" file
call :check_critical_file "source manifest" "%SOURCE_MANIFEST%" file
call :check_critical_file "primary source wrapper" "%STOCK_SOURCES_WRAPPER%" file
call :check_critical_file "legacy source wrapper" "%LEGACY_SOURCES_WRAPPER%" file
exit /b 0

:check_critical_file
set "VERIFY_CRITICAL_NAME=%~1"
set "VERIFY_CRITICAL_PATH=%~2"
set "VERIFY_CRITICAL_KIND=%~3"
powershell.exe -NoLogo -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('VERIFY_CRITICAL_PATH'); $root=[IO.Path]::GetFullPath([Environment]::GetEnvironmentVariable('VERIFY_ROOT')).TrimEnd([char]92); $kind=[Environment]::GetEnvironmentVariable('VERIFY_CRITICAL_KIND'); try{$full=[IO.Path]::GetFullPath($p).TrimEnd([char]92)}catch{exit 1}; if([string]::IsNullOrWhiteSpace($p) -or -not($full -ieq $root -or $full.StartsWith($root+([char]92),[StringComparison]::OrdinalIgnoreCase))){exit 2}; $cursor=$full; while($true){$i=Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue; if(-not $i -or (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){exit 3}; if($cursor -ieq $root){break}; $parent=[IO.Directory]::GetParent($cursor); if($null -eq $parent -or $parent.FullName.TrimEnd([char]92) -ieq $cursor){exit 4}; $cursor=$parent.FullName.TrimEnd([char]92)}; $leaf=Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue; if(-not $leaf -or (($leaf.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){exit 3}; if($kind -ieq 'file' -and $leaf.PSIsContainer){exit 5}; if($kind -ieq 'directory' -and -not $leaf.PSIsContainer){exit 5}; exit 0"
if errorlevel 1 (
    echo [FAIL] Critical !VERIFY_CRITICAL_NAME! is missing, outside the fixed root, or is a reparse/non-regular path: !VERIFY_CRITICAL_PATH!
    set "CRITICAL_FILES_OK=0"
    set /a ERRORS+=1
) else echo [OK] Critical !VERIFY_CRITICAL_NAME! is a regular in-root file.
exit /b 0

:check_source_wrappers
set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%STOCK_SOURCES_WRAPPER%" --verify
set "VERIFY_WRAPPER_RC=%ERRORLEVEL%"
if defined TEST_MODE (call :record_source_wrapper_result "fixture DOWNLOAD_STOCK_SOURCES.cmd") else (call :record_source_wrapper_result "DOWNLOAD_STOCK_SOURCES.cmd")
call "%LEGACY_SOURCES_WRAPPER%" --verify
set "VERIFY_WRAPPER_RC=%ERRORLEVEL%"
if defined TEST_MODE (call :record_source_wrapper_result "fixture DOWNLOAD_LEGACY_SOURCES.cmd") else (call :record_source_wrapper_result "DOWNLOAD_LEGACY_SOURCES.cmd")
exit /b 0

:record_source_wrapper_result
set "VERIFY_WRAPPER_NAME=%~1"
if not "!VERIFY_WRAPPER_RC!"=="0" (
    echo [FAIL] !VERIFY_WRAPPER_NAME! --verify returned exit code !VERIFY_WRAPPER_RC!.
    set /a ERRORS+=1
) else echo [OK] !VERIFY_WRAPPER_NAME! --verify passed.
exit /b 0

:check_root_layout
if not exist "%VERIFY_ROOT%" (
    echo [FAIL] Fixed install root is missing: %VERIFY_ROOT%
    set /a ERRORS+=1
    exit /b 0
)
call :scope_guard "%VERIFY_ROOT%"
if errorlevel 1 (
    echo [FAIL] Install root is a reparse point or resolves outside its canonical scope: %VERIFY_ROOT%
    set /a ERRORS+=1
)
for %%P in ("%VERIFY_ROOT%\.git" "%VERIFY_ROOT%\.venv" "%VERIFY_ROOT%\scripts" "%VERIFY_ROOT%\scripts\setup" "%VERIFY_ROOT%\scripts\sources" "%VERIFY_ROOT%\scripts\compat") do (
    call :scope_guard "%%~P"
    if errorlevel 1 (
        echo [FAIL] Managed path is a reparse point or leaves the fixed scope: %%~P
        set /a ERRORS+=1
    )
)
if not exist "%VERIFY_ROOT%\.git" (
    echo [FAIL] Git metadata is missing: %VERIFY_ROOT%\.git
    set /a ERRORS+=1
)
if not exist "%VERIFY_ROOT%\scripts\sources" (
    echo [FAIL] Source manifest directory is missing: %VERIFY_ROOT%\scripts\sources
    set /a ERRORS+=1
)
if not exist "%PACKAGE_HELPER%" (
    echo [FAIL] Python package verifier is missing: %PACKAGE_HELPER%
    set /a ERRORS+=1
)
if not exist "%REQUIREMENTS_FILE%" (
    echo [FAIL] requirements.txt is missing: %REQUIREMENTS_FILE%
    set /a ERRORS+=1
)
call :check_git_metadata "%VERIFY_ROOT%\.git"
if "!VERIFY_GIT_META_OK!"=="0" set /a ERRORS+=1
exit /b 0

:find_git
if defined STOCK_VERIFY_GIT_EXE if defined TEST_MODE set "GIT_EXE=%STOCK_VERIFY_GIT_EXE%"
if not defined GIT_EXE for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined GIT_EXE set "GIT_EXE=%%~fG"
if not defined GIT_EXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_EXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GIT_EXE if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" set "GIT_EXE=%ProgramFiles(x86)%\Git\cmd\git.exe"
if not defined GIT_EXE (
    echo [FAIL] Git for Windows was not found.
    set /a ERRORS+=1
) else (
    for %%I in ("%GIT_EXE%") do set "GIT_EXE=%%~fI"
    if not exist "!GIT_EXE!" (
        echo [FAIL] Git executable is missing: !GIT_EXE!
        set /a ERRORS+=1
    ) else echo [OK] Git executable found: !GIT_EXE!
)
exit /b 0

:check_repository
if not defined GIT_EXE exit /b 0
if not exist "%VERIFY_ROOT%\.git" exit /b 0
call :verify_origin "%VERIFY_ROOT%" "%EXPECTED_ORIGIN%"
if errorlevel 1 set /a ERRORS+=1
call :git_status "%VERIFY_ROOT%"
if /I "!VERIFY_STATUS!"=="DIRTY" (
    echo [WARN] Main repository is dirty; no repair or update is attempted.
    set /a WARNINGS+=1
) else if /I "!VERIFY_STATUS!"=="CLEAN" (
    echo [OK] Main repository status is clean.
) else (
    echo [WARN] Main repository status could not be determined; no update is attempted.
    set /a WARNINGS+=1
)
exit /b 0

:check_user_environment
for %%I in ("%VERIFY_ROOT%\..") do set "VERIFY_SHARED_ROOT=%%~fI"
call :check_env_entry "STOCK_HOME" "%VERIFY_ROOT%"
call :check_env_entry "STOCK_REPO" "%VERIFY_ROOT%"
call :check_env_entry "STOCK_SHARED_ROOT" "%VERIFY_SHARED_ROOT%"
call :check_env_entry "STOCK_VENV" "%VENV_DIR%"
call :check_env_entry "STOCK_PYTHON" "%VENV_PYTHON%"
call :check_env_entry "STOCK_EXTERNAL_REPOS" "%VERIFY_ROOT%\repos"
exit /b 0

:check_env_entry
set "VERIFY_ENV_NAME=%~1"
set "VERIFY_ENV_EXPECTED=%~2"
powershell.exe -NoLogo -NoProfile -Command "$name=[Environment]::GetEnvironmentVariable('VERIFY_ENV_NAME'); $expected=[Environment]::GetEnvironmentVariable('VERIFY_ENV_EXPECTED'); $raw=[Environment]::GetEnvironmentVariable('STOCK_VERIFY_USER_VARS'); $actual=$null; if(-not [string]::IsNullOrWhiteSpace($raw)){foreach($pair in ($raw -split ';')){if($pair -match '^([^=]+)=(.*)$' -and $Matches[1] -ieq $name){$actual=$Matches[2];break}}}; if($null -eq $actual){$actual=[Environment]::GetEnvironmentVariable($name,'User')}; if([string]::IsNullOrWhiteSpace($actual)){exit 1}; try{$a=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($actual)).TrimEnd([char]92);$e=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($expected)).TrimEnd([char]92)}catch{exit 1}; if($a -ieq $e){exit 0}else{exit 1}"
if not errorlevel 1 (
    echo [OK] User environment %VERIFY_ENV_NAME% is configured.
) else (
    echo [FAIL] User environment %VERIFY_ENV_NAME% is missing or incorrect.
    set /a ERRORS+=1
)
exit /b 0

:check_user_path
set "VERIFY_PATH_EXPECTED=%VERIFY_ROOT%"
call :check_path_entry
set "VERIFY_PATH_EXPECTED=%VENV_SCRIPTS%"
call :check_path_entry
set "VERIFY_PATH_EXPECTED=%VERIFY_ROOT%\scripts"
call :check_path_entry
set "VERIFY_PATH_EXPECTED=%VERIFY_ROOT%\scripts\setup"
call :check_path_entry
set "VERIFY_PATH_EXPECTED=%VERIFY_ROOT%\scripts\sources"
call :check_path_entry
set "VERIFY_PATH_EXPECTED=%VERIFY_ROOT%\scripts\compat"
call :check_path_entry
exit /b 0

:check_path_entry
set "VERIFY_PATH_RESULT=1"
powershell.exe -NoLogo -NoProfile -Command "$raw=[Environment]::GetEnvironmentVariable('STOCK_VERIFY_USER_PATH'); if([string]::IsNullOrWhiteSpace($raw)){$raw=[Environment]::GetEnvironmentVariable('Path','User')}; $target=[Environment]::ExpandEnvironmentVariables([string]$env:VERIFY_PATH_EXPECTED).Trim().Trim('"').TrimEnd([char]92); $ok=$false; foreach($entry in ($raw -split ';')){$candidate=[Environment]::ExpandEnvironmentVariables([string]$entry).Trim().Trim('"').TrimEnd([char]92); if(-not [string]::IsNullOrWhiteSpace($candidate)){try{$candidate=[IO.Path]::GetFullPath($candidate)}catch{}; if($candidate -ieq $target){$ok=$true; break}}}; if($ok){exit 0}else{exit 1}"
if not errorlevel 1 (
    echo [OK] User PATH contains %VERIFY_PATH_EXPECTED%
) else (
    echo [FAIL] User PATH is missing %VERIFY_PATH_EXPECTED%
    set /a ERRORS+=1
)
exit /b 0

:check_venv
call :scope_guard "%VENV_DIR%"
if errorlevel 1 (
    echo [FAIL] Virtual environment leaves the fixed scope: %VENV_DIR%
    set /a ERRORS+=1
)
call :scope_guard "%VENV_SCRIPTS%"
if errorlevel 1 (
    echo [FAIL] Virtual environment Scripts path leaves the fixed scope: %VENV_SCRIPTS%
    set /a ERRORS+=1
)
if not exist "%VENV_PYTHON%" (
    echo [FAIL] Managed venv Python is missing: %VENV_PYTHON%
    set /a ERRORS+=1
    exit /b 0
)
set "PYTHONDONTWRITEBYTECODE=1"
call :run_venv --version >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Managed venv Python could not start.
    set /a ERRORS+=1
) else echo [OK] Managed venv Python starts.
set "VERIFY_PYTHON_VERSION="
for /f "delims=" %%V in ('powershell.exe -NoLogo -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('VENV_PYTHON'); try{$v=& $p -c 'import sys; print(sys.version_info[0],sys.version_info[1],sys.version_info[2],sep=chr(46))' 2^>$null; if($LASTEXITCODE -eq 0){$v | Select-Object -Last 1}}catch{}"') do set "VERIFY_PYTHON_VERSION=%%V"
for /f "tokens=1-3 delims=." %%A in ("!VERIFY_PYTHON_VERSION!") do set /a VERIFY_PYTHON_MAJOR=%%A, VERIFY_PYTHON_MINOR=%%B
if not defined VERIFY_PYTHON_VERSION (
    echo [FAIL] Managed venv Python version could not be read.
    set /a ERRORS+=1
) else if !VERIFY_PYTHON_MAJOR! NEQ 3 (
    echo [FAIL] Managed venv Python must be 3.10-3.12: !VERIFY_PYTHON_VERSION!
    set /a ERRORS+=1
) else if !VERIFY_PYTHON_MINOR! LSS 10 (
    echo [FAIL] Managed venv Python must be 3.10-3.12: !VERIFY_PYTHON_VERSION!
    set /a ERRORS+=1
) else if !VERIFY_PYTHON_MINOR! GTR 12 (
    echo [FAIL] Managed venv Python must be 3.10-3.12: !VERIFY_PYTHON_VERSION!
    set /a ERRORS+=1
) else echo [OK] Managed venv Python version is !VERIFY_PYTHON_VERSION! (supported 3.10-3.12).
call :run_venv -m pip --version >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Managed venv pip is missing or unusable.
    set /a ERRORS+=1
) else echo [OK] Managed venv pip is available.
call :run_venv -m pip check
if errorlevel 1 (
    echo [FAIL] pip check reported broken requirements.
    set /a ERRORS+=1
) else echo [OK] pip check passed.
echo [INFO] Checking all direct requirements with import aliases and installed distributions...
call :run_venv "%PACKAGE_HELPER%" --requirements "%REQUIREMENTS_FILE%"
if errorlevel 1 (
    echo [FAIL] Direct requirement import/distribution verification failed.
    set /a ERRORS+=1
) else echo [OK] Direct requirement import/distribution verification passed.
exit /b 0

:run_venv
if /I "!VENV_PYTHON:~-4!"==".cmd" (
    call "!VENV_PYTHON!" %~1 %~2 %~3 %~4 %~5 %~6
) else (
    "!VENV_PYTHON!" %~1 %~2 %~3 %~4 %~5 %~6
)
exit /b !ERRORLEVEL!

:check_primary_sources_v1
set "VERIFY_MANIFEST=%SOURCE_MANIFEST%"
set /a PRIMARY_COUNT=0
set /a PRIMARY_DEFAULT_COUNT=0
set /a LEGACY_COUNT=0
if not exist "!VERIFY_MANIFEST!" (
    echo [FAIL] Primary source manifest is missing: !VERIFY_MANIFEST!
    set /a ERRORS+=1
    exit /b 0
)
set "VERIFY_MANIFEST_META="
set "VERIFY_MANIFEST_ERROR="
for /f "tokens=1-6 delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try{$j=Get-Content -LiteralPath $env:VERIFY_MANIFEST -Raw | ConvertFrom-Json; if([int]$j.schema_version -ne 1){throw 'schema_version must be 1'}; $s=@($j.sources); if($s.Count -ne 39){throw ('source count must be 39, got ' + $s.Count)}; $ids=@($s|ForEach-Object {[string]$_.id}); $targets=@($s|ForEach-Object {[string]$_.target}); if(($ids|Sort-Object -Unique).Count -ne $ids.Count){throw 'source ids are not unique'}; if(($targets|Sort-Object -Unique).Count -ne $targets.Count){throw 'source targets are not unique'}; $p=@($s|Where-Object {$_.scope -eq 'primary'}); $d=@($p|Where-Object {[bool]$_.default_install}); $l=@($s|Where-Object {$_.scope -eq 'legacy'}); $a=@($j.legacy_aliases); $aliasSourceId=''; if($a.Count -eq 1){$aliasSourceId=[string]$a[0].source_id}; $tw=@($s|Where-Object {[string]$_.id -eq 'twstock'}); $twTarget=''; if($tw.Count -eq 1){$twTarget=[string]$tw[0].target}; if($p.Count -ne 37 -or $l.Count -ne 2 -or $d.Count -ne 3 -or $a.Count -ne 1 -or $aliasSourceId -ne 'twstock' -or $tw.Count -ne 1 -or $twTarget -ne 'taiwan_market_data\twstock'){throw 'manifest scope/default counts or legacy twstock alias are invalid'}; Write-Output ('META|' + $p.Count + '|' + $d.Count + '|' + $l.Count + '|' + $a.Count); foreach($x in $s){$target=[string]$x.target;$url=[string]$x.url;$id=[string]$x.id;if($target -notmatch '^[A-Za-z0-9_.-]+\\[A-Za-z0-9_.-]+$' -or $id -notmatch '^[A-Za-z0-9_.-]+$' -or $url -notmatch '^https://github.com/[^/]+/[^/]+\.git$'){throw 'source manifest contains unsafe identity fields'}; Write-Output ('SRC|' + [string]$x.scope + '|' + $target + '|' + $url + '|' + ([bool]$x.default_install) + '|' + $id)}}catch{Write-Output ('ERROR|' + $_.Exception.Message);exit 1}"') do call :record_manifest_row "%%~A" "%%~B" "%%~C" "%%~D" "%%~E" "%%~F"
if defined VERIFY_MANIFEST_ERROR goto :manifest_invalid
if not defined VERIFY_MANIFEST_META goto :manifest_no_records
for /f "tokens=1-4 delims=|" %%A in ("!VERIFY_MANIFEST_META!") do call :record_manifest_meta META "%%~A" "%%~B" "%%~C" "%%~D"
exit /b 0

:record_manifest_row
set "VERIFY_ROW_TYPE=%~1"
if /I "%VERIFY_ROW_TYPE%"=="META" (
    call :record_manifest_meta META "%~2" "%~3" "%~4" "%~5"
    exit /b 0
)
if /I "%VERIFY_ROW_TYPE%"=="ERROR" set "VERIFY_MANIFEST_ERROR=%~2" & exit /b 0
if /I not "%VERIFY_ROW_TYPE%"=="SRC" exit /b 0
set "VERIFY_ROW_SCOPE=%~2"
if /I "%VERIFY_ROW_SCOPE%"=="legacy" set /a LEGACY_COUNT+=1 & exit /b 0
if /I not "%VERIFY_ROW_SCOPE%"=="primary" exit /b 0
set /a PRIMARY_COUNT+=1
if /I "%~5"=="True" goto :record_manifest_primary_default
call :check_source_identity "%~3" "%~4" "primary"
exit /b 0

:record_manifest_primary_default
set /a PRIMARY_DEFAULT_COUNT+=1
call :check_source_identity "%~3" "%~4" "primary-default"
exit /b 0

:record_manifest_meta
set "VERIFY_MANIFEST_META=%~2|%~3|%~4|%~5"
set /a MANIFEST_LEGACY_COUNT=%~4
set /a LEGACY_ALIAS_COUNT=%~5
if not "%~2"=="37" goto :manifest_meta_primary_bad
echo [OK] Primary source manifest identity count is 37.
goto :manifest_meta_default

:manifest_meta_primary_bad
echo [FAIL] Primary source manifest identity count is %~2; expected 37.
set /a ERRORS+=1

:manifest_meta_default
if not "%~3"=="3" goto :manifest_meta_default_bad
echo [OK] Primary default source count is 3.
goto :manifest_meta_legacy

:manifest_meta_default_bad
echo [FAIL] Primary default source count is %~3; expected 3.
set /a ERRORS+=1

:manifest_meta_legacy
if "%~4"=="%MANIFEST_LEGACY_COUNT%" goto :manifest_meta_alias
echo [WARN] Manifest legacy source count differs while parsing: %~4 vs %MANIFEST_LEGACY_COUNT%.
set /a WARNINGS+=1

:manifest_meta_alias
if not "%~5"=="1" goto :manifest_meta_alias_bad
echo [OK] Legacy alias count is exactly 1 - twstock shared alias.
exit /b 0

:manifest_meta_alias_bad
echo [FAIL] Legacy alias count is %~5; expected exactly 1 twstock shared alias.
set /a ERRORS+=1
exit /b 0

:manifest_invalid
echo [FAIL] Source manifest is invalid: !VERIFY_MANIFEST_ERROR!
set /a ERRORS+=1
exit /b 0

:manifest_no_records
echo [FAIL] Source manifest produced no schema records.
set /a ERRORS+=1
exit /b 0

:check_legacy_sources_v1
if !LEGACY_COUNT! LSS 2 (
    echo [WARN] Optional legacy source entries are incomplete: !LEGACY_COUNT! unique entries observed.
    set /a WARNINGS+=1
) else echo [OK] Optional legacy source entries observed: !LEGACY_COUNT!.
exit /b 0

:check_source_identity
set "VERIFY_REL=%~1"
set "VERIFY_EXPECTED_ORIGIN=%~2"
set "VERIFY_KIND=%~3"
call :validate_relative "!VERIFY_REL!" "!VERIFY_KIND!"
if errorlevel 1 (
    set /a INVALID_SOURCES+=1
    set /a ERRORS+=1
    exit /b 0
)
set "VERIFY_TARGET=%VERIFY_ROOT%\repos\!VERIFY_REL!"
call :scope_guard "!VERIFY_TARGET!"
if errorlevel 1 (
    echo [FAIL] !VERIFY_KIND! source leaves the canonical repos scope: !VERIFY_REL!
    set /a INVALID_SOURCES+=1
    set /a ERRORS+=1
    exit /b 0
)
if not exist "!VERIFY_TARGET!" (
    if /I "!VERIFY_KIND!"=="primary-default" (
        echo [FAIL] Required core source is not downloaded: !VERIFY_REL!
        set /a ERRORS+=1
    ) else echo [WARN] !VERIFY_KIND! source is not downloaded: !VERIFY_REL!
    if /I "!VERIFY_KIND!"=="legacy" (set /a LEGACY_MISSING+=1) else (set /a PRIMARY_MISSING+=1)
    if /I not "!VERIFY_KIND!"=="primary-default" set /a WARNINGS+=1
    exit /b 0
)
if not exist "!VERIFY_TARGET!\.git" (
    echo [FAIL] !VERIFY_KIND! source is not a Git repository: !VERIFY_REL!
    set /a INVALID_SOURCES+=1
    set /a ERRORS+=1
    exit /b 0
)
call :scope_guard "!VERIFY_TARGET!\.git"
if errorlevel 1 (
    echo [FAIL] !VERIFY_KIND! source Git metadata leaves the canonical scope: !VERIFY_REL!
    set /a INVALID_SOURCES+=1
    set /a ERRORS+=1
    exit /b 0
)
call :check_git_metadata "!VERIFY_TARGET!\.git"
if "!VERIFY_GIT_META_OK!"=="0" (
    set /a INVALID_SOURCES+=1
    set /a ERRORS+=1
    exit /b 0
)
call :verify_origin "!VERIFY_TARGET!" "!VERIFY_EXPECTED_ORIGIN!"
if errorlevel 1 (
    set /a INVALID_SOURCES+=1
    set /a ERRORS+=1
    exit /b 0
)
call :git_status "!VERIFY_TARGET!"
if /I "!VERIFY_STATUS!"=="DIRTY" (
    echo [WARN] !VERIFY_KIND! source is dirty; no update is attempted: !VERIFY_REL!
    set /a WARNINGS+=1
) else if /I "!VERIFY_STATUS!"=="CLEAN" (
    echo [OK] !VERIFY_KIND! source origin/scope verified: !VERIFY_REL!
) else (
    echo [WARN] !VERIFY_KIND! source status is unreadable; no update is attempted: !VERIFY_REL!
    set /a WARNINGS+=1
)
exit /b 0

:validate_relative
set "CHECK_REL=%~1"
set "CHECK_KIND=%~2"
if not defined CHECK_REL exit /b 1
if not "%CHECK_REL%"=="%CHECK_REL:..=%" exit /b 1
if not "%CHECK_REL%"=="%CHECK_REL:/=%" exit /b 1
set "CHECK_CATEGORY="
set "CHECK_REPO="
set "CHECK_EXTRA="
for /f "tokens=1,2,* delims=\" %%A in ("!CHECK_REL!") do (
    set "CHECK_CATEGORY=%%A"
    set "CHECK_REPO=%%B"
    set "CHECK_EXTRA=%%C"
)
if not defined CHECK_CATEGORY exit /b 1
if not defined CHECK_REPO exit /b 1
if defined CHECK_EXTRA exit /b 1
if /I not "!CHECK_KIND!"=="legacy" (
    set "CATEGORY_OK="
    for %%C in (taiwan_market_data global_market_data machine_learning_forecasting backtesting_engines quant_portfolio_risk) do if /I "%%C"=="!CHECK_CATEGORY!" set "CATEGORY_OK=1"
) else (
    set "CATEGORY_OK="
    if /I "!CHECK_CATEGORY!"=="taiwan_market_data" set "CATEGORY_OK=1"
    if /I "!CHECK_CATEGORY!"=="legacy_compat" set "CATEGORY_OK=1"
)
if not defined CATEGORY_OK exit /b 1
exit /b 0

:check_git_metadata
set "VERIFY_GIT_META=%~1"
set "VERIFY_GIT_META_OK=1"
powershell.exe -NoLogo -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('VERIFY_GIT_META'); $i=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; if(-not $i){exit 1}; if((($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){exit 4}; if($i.PSIsContainer){exit 0}; $line=(Get-Content -LiteralPath $p -TotalCount 1 -ErrorAction SilentlyContinue); if($line -notmatch '^gitdir:\s*(.+)$'){exit 2}; $g=$Matches[1].Trim(); if(-not [IO.Path]::IsPathRooted($g)){$g=Join-Path ([IO.Path]::GetDirectoryName($p)) $g}; $g=[IO.Path]::GetFullPath($g); $root=[IO.Path]::GetFullPath([Environment]::GetEnvironmentVariable('VERIFY_ROOT')).TrimEnd([char]92); if(-not ($g -ieq $root -or $g.StartsWith($root+([char]92),[StringComparison]::OrdinalIgnoreCase))){exit 3}; $gi=Get-Item -LiteralPath $g -Force -ErrorAction SilentlyContinue; if(-not $gi){exit 3}; $cursor=$g; while($true){$ci=Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue; if(-not $ci -or (($ci.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){exit 4}; if($cursor -ieq $root){break}; $parent=[IO.Directory]::GetParent($cursor); if($null -eq $parent -or $parent.FullName -ieq $cursor){exit 3}; $cursor=$parent.FullName.TrimEnd([char]92)}; exit 0"
if errorlevel 1 (
    echo [FAIL] Git metadata is missing, external, or unsafe: %VERIFY_GIT_META%
    set "VERIFY_GIT_META_OK=0"
)
exit /b 0

:scope_guard
set "VERIFY_SCOPE_PATH=%~1"
powershell.exe -NoLogo -NoProfile -Command "$root=[IO.Path]::GetFullPath([Environment]::GetEnvironmentVariable('VERIFY_ROOT')).TrimEnd([char]92); $path=[IO.Path]::GetFullPath([Environment]::GetEnvironmentVariable('VERIFY_SCOPE_PATH')).TrimEnd([char]92); function InScope([string]$p){if([string]::IsNullOrWhiteSpace($p)){return $false}; $f=[IO.Path]::GetFullPath($p).TrimEnd([char]92); return ($f -ieq $root -or $f.StartsWith($root+([char]92),[StringComparison]::OrdinalIgnoreCase))}; function ResolveLink($i){$current=$i; for($n=0;$n -lt 8;$n++){if((($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)){return [IO.Path]::GetFullPath($current.FullName)}; $targets=@($current.Target); if($targets.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$targets[0])){return $null}; $next=[string]$targets[0]; if(-not [IO.Path]::IsPathRooted($next)){$next=Join-Path $current.DirectoryName $next}; $next=[IO.Path]::GetFullPath($next); if(-not (Test-Path -LiteralPath $next)){return $null}; $current=Get-Item -LiteralPath $next -Force -ErrorAction SilentlyContinue; if(-not $current){return $null}}; return $null}; if(-not (InScope $path)){exit 2}; $cursor=$path; while($true){$i=Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue; if($i){$reparse=(($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0); if($reparse){$r=ResolveLink $i; if($null -eq $r){exit 3}; if(-not (InScope $r)){exit 4}; exit 5}}; if($cursor -ieq $root){break}; $parent=[IO.Directory]::GetParent($cursor); if($null -eq $parent -or $parent.FullName -ieq $cursor){exit 6}; $cursor=$parent.FullName.TrimEnd([char]92)}; exit 0"
if errorlevel 1 exit /b 1
exit /b 0

:verify_origin
set "VERIFY_TARGET=%~1"
set "VERIFY_EXPECTED_ORIGIN=%~2"
call :scope_guard "%VERIFY_TARGET%"
if errorlevel 1 (
    echo [FAIL] Git target is outside its canonical scope: %VERIFY_TARGET%
    exit /b 1
)
set "VERIFY_GIT_EXE=%GIT_EXE%"
powershell.exe -NoLogo -NoProfile -Command "$git=[Environment]::GetEnvironmentVariable('VERIFY_GIT_EXE'); $t=[Environment]::GetEnvironmentVariable('VERIFY_TARGET'); $expected=[Environment]::GetEnvironmentVariable('VERIFY_EXPECTED_ORIGIN'); if(-not (Test-Path -LiteralPath $git)){Write-Output '[FAIL] Git executable is unavailable'; exit 1}; $actual=(& $git -C $t remote get-url origin 2>$null | Select-Object -First 1); function Normalize([string]$v){if([string]::IsNullOrWhiteSpace($v)){return ''}; $x=$v.Trim().TrimEnd('/'); $p=''; if($x -imatch '^git@github\.com:(?<p>[^/]+/[^/]+)$'){$p=$Matches.p} elseif($x -imatch '^ssh://git@github\.com/(?<p>[^/]+/[^/]+)$'){$p=$Matches.p} elseif($x -imatch '^https?://(?:www\.)?github\.com/(?<p>[^/]+/[^/]+)$'){$p=$Matches.p} else{return ''}; $p=$p.TrimEnd('/'); if($p.EndsWith('.git',[StringComparison]::OrdinalIgnoreCase)){$p=$p.Substring(0,$p.Length-4)}; if($p -notmatch '^[^/]+/[^/]+$'){return ''}; return ('github://' + $p).ToLowerInvariant()}; $a=Normalize $actual; $e=Normalize $expected; if(-not [string]::IsNullOrWhiteSpace($a) -and $a -ceq $e){exit 0}; Write-Output ('[FAIL] Git origin mismatch: ' + $t); Write-Output (' expected: ' + $expected); Write-Output (' actual:   ' + [string]$actual); exit 1"
if errorlevel 1 exit /b 1
echo [OK] Git origin verified: %VERIFY_TARGET%
exit /b 0

:git_status
set "VERIFY_TARGET=%~1"
set "VERIFY_STATUS="
set "VERIFY_GIT_EXE=%GIT_EXE%"
powershell.exe -NoLogo -NoProfile -Command "$git=[Environment]::GetEnvironmentVariable('VERIFY_GIT_EXE'); $t=[Environment]::GetEnvironmentVariable('VERIFY_TARGET'); if(-not (Test-Path -LiteralPath $git)){exit 1}; $s=@(& $git -C $t status --porcelain=v1 --untracked-files=all 2>$null); if($s.Count -gt 0){exit 2}else{exit 0}"
if errorlevel 2 (set "VERIFY_STATUS=DIRTY") else if errorlevel 1 (set "VERIFY_STATUS=UNKNOWN") else set "VERIFY_STATUS=CLEAN"
exit /b 0

:check_junctions
if /I "%STOCK_VERIFY_SKIP_JUNCTIONS%"=="1" if defined TEST_MODE (
    echo [INFO] Junction scan skipped in test fixture.
    exit /b 0
)
if not exist "%VERIFY_ROOT%" (
    echo [WARN] Junction scan skipped because the install root is missing.
    set /a JUNCTION_COUNT=0
    set /a WARNINGS+=1
    exit /b 0
)
set "VERIFY_JUNCTION_RESULT="
for /f "delims=" %%J in ('powershell.exe -NoLogo -NoProfile -Command "$root=[IO.Path]::GetFullPath([Environment]::GetEnvironmentVariable('VERIFY_ROOT')).TrimEnd([char]92); function InScope([string]$p){if([string]::IsNullOrWhiteSpace($p)){return $false}; $f=[IO.Path]::GetFullPath($p).TrimEnd([char]92); return ($f -ieq $root -or $f.StartsWith($root+([char]92),[StringComparison]::OrdinalIgnoreCase))}; function ResolveLink($i){$current=$i; for($n=0;$n -lt 8;$n++){if((($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)){return [IO.Path]::GetFullPath($current.FullName)}; $targets=@($current.Target); if($targets.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$targets[0])){return $null}; $next=[string]$targets[0]; if(-not [IO.Path]::IsPathRooted($next)){$next=Join-Path $current.DirectoryName $next}; $next=[IO.Path]::GetFullPath($next); if(-not (Test-Path -LiteralPath $next)){return $null}; $current=Get-Item -LiteralPath $next -Force -ErrorAction SilentlyContinue; if(-not $current){return $null}}; return $null}; $stack=New-Object System.Collections.Stack; $stack.Push((Get-Item -LiteralPath $root -Force)); $items=New-Object System.Collections.ArrayList; while($stack.Count -gt 0){$d=$stack.Pop(); foreach($i in @(Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue)){if(($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){[void]$items.Add($i); continue}; if($i.PSIsContainer){$stack.Push($i)}}}; $bad=0; foreach($i in $items){$r=ResolveLink $i; if($null -eq $r -or -not (InScope $r)){$bad++}}; Write-Output ($items.Count.ToString()+','+$bad.ToString())"') do set "VERIFY_JUNCTION_RESULT=%%J"
for /f "tokens=1,2 delims=," %%A in ("!VERIFY_JUNCTION_RESULT!") do (
    set /a JUNCTION_COUNT=%%A
    set /a JUNCTION_BAD=%%B
)
if not defined VERIFY_JUNCTION_RESULT (
    echo [FAIL] Junction scan could not be completed.
    set /a ERRORS+=1
    exit /b 0
)
if !JUNCTION_BAD! GTR 0 (
    echo [FAIL] !JUNCTION_BAD! reparse targets leave %VERIFY_ROOT%.
    set /a ERRORS+=1
) else echo [OK] Reparse targets are confined to %VERIFY_ROOT%.
if !JUNCTION_COUNT! EQU !EXPECTED_JUNCTIONS! (
    echo [OK] Junction count is !JUNCTION_COUNT! - reference !EXPECTED_JUNCTIONS!.
) else (
    echo [WARN] Junction count is !JUNCTION_COUNT! - reference !EXPECTED_JUNCTIONS!; no repair is attempted.
    set /a WARNINGS+=1
)
if not defined TEST_MODE if not defined STOCK_VERIFY_SKIP_LEGACY_LINK call :check_legacy_link
exit /b 0

:check_legacy_link
if not exist "D:\Downloads\stock" (
    echo [WARN] Optional legacy path is absent: D:\Downloads\stock
    set /a WARNINGS+=1
    exit /b 0
)
set "VERIFY_LEGACY_LINK=D:\Downloads\stock"
set "VERIFY_LEGACY_TARGET="
powershell.exe -NoLogo -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('VERIFY_LEGACY_LINK'); $expected=[Environment]::GetEnvironmentVariable('EXPECTED_ROOT'); $i=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; if(-not $i -or (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)){exit 1}; $targets=@($i.Target); if($targets.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$targets[0])){exit 1}; $t=[string]$targets[0]; if(-not [IO.Path]::IsPathRooted($t)){$t=Join-Path $i.DirectoryName $t}; $t=[IO.Path]::GetFullPath($t).TrimEnd([char]92); if($t -ieq $expected){exit 0}else{exit 1}"
if not errorlevel 1 set "VERIFY_LEGACY_TARGET=%EXPECTED_ROOT%"
if /I "!VERIFY_LEGACY_TARGET!"=="%EXPECTED_ROOT%" (
    echo [OK] Optional legacy junction points to %EXPECTED_ROOT%.
) else (
    echo [WARN] Optional legacy path exists but does not point to %EXPECTED_ROOT%; it was not modified.
    set /a WARNINGS+=1
)
exit /b 0
