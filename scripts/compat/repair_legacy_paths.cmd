@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Repair stock toolkit compatibility paths

rem Production is fixed to D:\stock\GitHub. Test overrides are accepted only
rem when both roots are inside the current user TEMP directory and are
rem validated below; production never reads these environment variables.
set "EXPECTED_REPO_ROOT=D:\stock\GitHub"
set "EXPECTED_LEGACY_ROOT=D:\Downloads\stock"
set "REPO_ROOT=%EXPECTED_REPO_ROOT%"
set "LEGACY_ROOT=%EXPECTED_LEGACY_ROOT%"
set "REPAIR_TEST_MODE="
if /I "%STOCK_REPAIR_TEST_MODE%"=="1" (
    if not defined STOCK_REPAIR_ROOT (
        echo [ERROR] Test mode requires STOCK_REPAIR_ROOT.
        exit /b 2
    )
    if not defined STOCK_REPAIR_LEGACY_ROOT (
        echo [ERROR] Test mode requires STOCK_REPAIR_LEGACY_ROOT.
        exit /b 2
    )
    set "REPAIR_TEST_MODE=1"
    set "REPO_ROOT=%STOCK_REPAIR_ROOT%"
    set "LEGACY_ROOT=%STOCK_REPAIR_LEGACY_ROOT%"
)
set "MODE="
set /a CREATED_COUNT=0
set /a SKIPPED_COUNT=0
set /a FAILED_COUNT=0

if /I "%~1"=="--check" if "%~2"=="" set "MODE=CHECK"
if /I "%~1"=="--apply" if /I "%~2"=="--confirm" set "MODE=APPLY"
if not defined MODE (
    echo [ERROR] Explicit confirmation is required.
    echo Usage: repair_legacy_paths.cmd --check
    echo        repair_legacy_paths.cmd --apply --confirm
    exit /b 2
)

if /I "%MODE%"=="CHECK" echo Check mode is read-only; no directories or junctions will be created.
if /I "%MODE%"=="APPLY" echo Apply mode creates only missing junctions after scope checks.
if not defined REPAIR_TEST_MODE if not exist "D:\" (
    echo [ERROR] Drive D: was not found.
    exit /b 1
)

call :validate_root_layout
if errorlevel 1 exit /b 1

echo ============================================================
echo Stock compatibility path validation and repair
echo ============================================================
echo Repository: %REPO_ROOT%
echo Legacy path: %LEGACY_ROOT%
echo.

if /I "%REPAIR_TEST_MODE%"=="1" goto test_link_subset
call :check_link "%LEGACY_ROOT%" "%REPO_ROOT%"
call :check_link "%REPO_ROOT%\repos\tw_data" "%REPO_ROOT%\repos\taiwan_market_data"
call :check_link "%REPO_ROOT%\repos\market_data" "%REPO_ROOT%\repos\global_market_data"
call :check_link "%REPO_ROOT%\repos\ml" "%REPO_ROOT%\repos\machine_learning_forecasting"
call :check_link "%REPO_ROOT%\repos\backtests" "%REPO_ROOT%\repos\backtesting_engines"
call :check_link "%REPO_ROOT%\repos\quant_tools" "%REPO_ROOT%\repos\quant_portfolio_risk"
call :check_link "%REPO_ROOT%\repos\ai_tools" "%REPO_ROOT%\repos\ai_agent_tools"
call :check_link "%REPO_ROOT%\repos\legacy" "%REPO_ROOT%\repos\legacy_compat"

call :check_link "%REPO_ROOT%\repos\FinMind" "%REPO_ROOT%\repos\taiwan_market_data\FinMind"
call :check_link "%REPO_ROOT%\repos\daily_stock_analysis" "%REPO_ROOT%\repos\taiwan_market_data\daily_stock_analysis"
call :check_link "%REPO_ROOT%\repos\stock-strategies-only" "%REPO_ROOT%\repos\taiwan_market_data\stock-strategies-only"
call :check_link "%REPO_ROOT%\repos\CasualMarket" "%REPO_ROOT%\repos\taiwan_market_data\CasualMarket"
call :check_link "%REPO_ROOT%\repos\twstock" "%REPO_ROOT%\repos\taiwan_market_data\twstock"
call :check_link "%REPO_ROOT%\repos\PyConTW2018Tutorial" "%REPO_ROOT%\repos\taiwan_market_data\PyConTW2018Tutorial"
call :check_link "%REPO_ROOT%\repos\yfinance" "%REPO_ROOT%\repos\global_market_data\yfinance"
call :check_link "%REPO_ROOT%\repos\OpenBB" "%REPO_ROOT%\repos\global_market_data\OpenBB"
call :check_link "%REPO_ROOT%\repos\qlib" "%REPO_ROOT%\repos\machine_learning_forecasting\qlib"
call :check_link "%REPO_ROOT%\repos\FinRL" "%REPO_ROOT%\repos\machine_learning_forecasting\FinRL"
call :check_link "%REPO_ROOT%\repos\darts" "%REPO_ROOT%\repos\machine_learning_forecasting\darts"
call :check_link "%REPO_ROOT%\repos\mlforecast" "%REPO_ROOT%\repos\machine_learning_forecasting\mlforecast"
call :check_link "%REPO_ROOT%\repos\neuralforecast" "%REPO_ROOT%\repos\machine_learning_forecasting\neuralforecast"
call :check_link "%REPO_ROOT%\repos\statsforecast" "%REPO_ROOT%\repos\machine_learning_forecasting\statsforecast"
call :check_link "%REPO_ROOT%\repos\LightGBM" "%REPO_ROOT%\repos\machine_learning_forecasting\LightGBM"
call :check_link "%REPO_ROOT%\repos\xgboost" "%REPO_ROOT%\repos\machine_learning_forecasting\xgboost"
call :check_link "%REPO_ROOT%\repos\catboost" "%REPO_ROOT%\repos\machine_learning_forecasting\catboost"
call :check_link "%REPO_ROOT%\repos\optuna" "%REPO_ROOT%\repos\machine_learning_forecasting\optuna"
call :check_link "%REPO_ROOT%\repos\shap" "%REPO_ROOT%\repos\machine_learning_forecasting\shap"
call :check_link "%REPO_ROOT%\repos\freqtrade" "%REPO_ROOT%\repos\machine_learning_forecasting\freqtrade"
call :check_link "%REPO_ROOT%\repos\vectorbt" "%REPO_ROOT%\repos\backtesting_engines\vectorbt"
call :check_link "%REPO_ROOT%\repos\backtesting.py" "%REPO_ROOT%\repos\backtesting_engines\backtesting-py"
call :check_link "%REPO_ROOT%\repos\Lean" "%REPO_ROOT%\repos\backtesting_engines\Lean"
call :check_link "%REPO_ROOT%\repos\bt" "%REPO_ROOT%\repos\backtesting_engines\bt"
call :check_link "%REPO_ROOT%\repos\zipline-reloaded" "%REPO_ROOT%\repos\backtesting_engines\zipline-reloaded"
call :check_link "%REPO_ROOT%\repos\backtrader" "%REPO_ROOT%\repos\backtesting_engines\backtrader"
call :check_link "%REPO_ROOT%\repos\ta-lib-python" "%REPO_ROOT%\repos\quant_portfolio_risk\ta-lib-python"
call :check_link "%REPO_ROOT%\repos\ta" "%REPO_ROOT%\repos\quant_portfolio_risk\ta"
call :check_link "%REPO_ROOT%\repos\alphalens-reloaded" "%REPO_ROOT%\repos\quant_portfolio_risk\alphalens-reloaded"
call :check_link "%REPO_ROOT%\repos\quantstats" "%REPO_ROOT%\repos\quant_portfolio_risk\quantstats"
call :check_link "%REPO_ROOT%\repos\pyfolio-reloaded" "%REPO_ROOT%\repos\quant_portfolio_risk\pyfolio-reloaded"
call :check_link "%REPO_ROOT%\repos\empyrical-reloaded" "%REPO_ROOT%\repos\quant_portfolio_risk\empyrical-reloaded"
call :check_link "%REPO_ROOT%\repos\ffn" "%REPO_ROOT%\repos\quant_portfolio_risk\ffn"
call :check_link "%REPO_ROOT%\repos\PyPortfolioOpt" "%REPO_ROOT%\repos\quant_portfolio_risk\PyPortfolioOpt"
call :check_link "%REPO_ROOT%\repos\Riskfolio-Lib" "%REPO_ROOT%\repos\quant_portfolio_risk\Riskfolio-Lib"
call :check_link "%REPO_ROOT%\repos\skfolio" "%REPO_ROOT%\repos\quant_portfolio_risk\skfolio"

call :check_link "%REPO_ROOT%\andrej-karpathy-skills" "%REPO_ROOT%\repos\ai_agent_tools\andrej-karpathy-skills"
call :check_link "%REPO_ROOT%\audio-tldr-skill" "%REPO_ROOT%\repos\ai_agent_tools\audio-tldr-skill"
call :check_link "%REPO_ROOT%\claude-code" "%REPO_ROOT%\repos\ai_agent_tools\claude-code"
call :check_link "%REPO_ROOT%\claude-code-i18n" "%REPO_ROOT%\repos\ai_agent_tools\claude-code-i18n"
call :check_link "%REPO_ROOT%\claude-code-resources" "%REPO_ROOT%\repos\ai_agent_tools\claude-code-resources"
call :check_link "%REPO_ROOT%\de-ai-tone" "%REPO_ROOT%\repos\ai_agent_tools\de-ai-tone"
call :check_link "%REPO_ROOT%\harness-engineering" "%REPO_ROOT%\repos\ai_agent_tools\harness-engineering"
call :check_link "%REPO_ROOT%\skills" "%REPO_ROOT%\repos\ai_agent_tools\skills"
call :check_link "%REPO_ROOT%\stocktw" "%REPO_ROOT%\repos\taiwan_market_data\stocktw"

call :check_link "%REPO_ROOT%\github_sources\twstock" "%REPO_ROOT%\repos\taiwan_market_data\twstock"
call :check_link "%REPO_ROOT%\github_sources\tw_stocker" "%REPO_ROOT%\repos\legacy_compat\tw_stocker"
call :check_link "%REPO_ROOT%\github_sources\python-stock-radar-" "%REPO_ROOT%\repos\legacy_compat\python-stock-radar-"
call :check_link "%REPO_ROOT%\github_sources\TW-stock" "%REPO_ROOT%\repos\legacy_compat\TW-stock"
goto processing_complete

:test_link_subset
rem Hidden fixture mode exercises only the approved external link and two
rem representative internal links; production always executes the full list.
call :check_link "%LEGACY_ROOT%" "%REPO_ROOT%"
call :check_link "%REPO_ROOT%\repos\twstock" "%REPO_ROOT%\repos\taiwan_market_data\twstock"
call :check_link "%REPO_ROOT%\github_sources\twstock" "%REPO_ROOT%\repos\taiwan_market_data\twstock"

:processing_complete

echo.
echo ============================================================
echo Compatibility processing complete: created !CREATED_COUNT!, skipped !SKIPPED_COUNT!, failed !FAILED_COUNT!
echo ============================================================
if !FAILED_COUNT! GTR 0 exit /b 1
exit /b 0

:validate_root_layout
set "ROOT_CHECK_RESULT="
set "REPAIR_SCOPE_REPO=%REPO_ROOT%"
set "REPAIR_SCOPE_LEGACY=%LEGACY_ROOT%"
for /f "delims=" %%A in ('powershell.exe -NoLogo -NoProfile -Command "$repo=[Environment]::GetEnvironmentVariable('REPAIR_SCOPE_REPO'); $legacy=[Environment]::GetEnvironmentVariable('REPAIR_SCOPE_LEGACY'); $test=([Environment]::GetEnvironmentVariable('REPAIR_TEST_MODE') -eq '1'); function Full([string]$p){try{$f=[IO.Path]::GetFullPath($p); if($f.Length -gt 3){$f=$f.TrimEnd([char]92)}; return $f}catch{return $null}}; function AncestorSafe([string]$p){$cursor=Full $p; if([string]::IsNullOrWhiteSpace($cursor)){return $false}; while($true){$i=Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue; if($i -and (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){return $false}; $parent=[IO.Directory]::GetParent($cursor); if($null -eq $parent -or $parent.FullName -ieq $cursor){break}; $cursor=$parent.FullName}; return $true}; function IsTemp([string]$p){$f=Full $p; $t=Full ([IO.Path]::GetTempPath()); return ($f -ieq $t -or $f.StartsWith($t+([char]92),[StringComparison]::OrdinalIgnoreCase))}; $r=Full $repo; $l=Full $legacy; if(-not $r -or -not $l){Write-Output 'FAIL|invalid root path'; exit 1}; if(-not $test -and $r -ine 'D:\stock\GitHub'){Write-Output 'FAIL|production root is not D:\stock\GitHub'; exit 1}; if(-not $test -and $l -ine 'D:\Downloads\stock'){Write-Output 'FAIL|production legacy root is not D:\Downloads\stock'; exit 1}; if($test -and (-not (IsTemp $r) -or -not (IsTemp $l))){Write-Output 'FAIL|test roots must be inside TEMP'; exit 1}; $ri=Get-Item -LiteralPath $r -Force -ErrorAction SilentlyContinue; if(-not $ri -or -not $ri.PSIsContainer -or (($ri.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){Write-Output 'FAIL|repository root must be a physical directory'; exit 1}; if(-not (AncestorSafe $r)){Write-Output 'FAIL|repository root has a reparse ancestor'; exit 1}; $lp=[IO.Directory]::GetParent($l); if($null -eq $lp -or -not (AncestorSafe $lp.FullName)){Write-Output 'FAIL|legacy parent has a reparse ancestor'; exit 1}; if($test -and $r -ieq $l){Write-Output 'FAIL|test roots must differ'; exit 1}; Write-Output 'OK'"') do set "ROOT_CHECK_RESULT=%%A"
if /I not "!ROOT_CHECK_RESULT!"=="OK" (
    echo [FAIL] !ROOT_CHECK_RESULT!
    exit /b 1
)
if /I "%REPAIR_TEST_MODE%"=="1" echo [INFO] Test-only TEMP roots are active.
exit /b 0

:check_link
for %%I in ("%~1") do set "LINK=%%~fI"
for %%I in ("%~2") do set "TARGET=%%~fI"
call :validate_scope "!LINK!" "!TARGET!"
if errorlevel 1 (
    set /a FAILED_COUNT+=1
    exit /b 0
)
set "PROBE_PATH=!TARGET!"
call :probe_path
if /I "!PROBE_KIND!"=="MISSING" (
    echo [SKIP] Source is not downloaded: !TARGET!
    set /a SKIPPED_COUNT+=1
    exit /b 0
)
if /I not "!PROBE_KIND!"=="DIR" (
    echo [FAIL] Source target is not a physical directory: !TARGET!
    set /a FAILED_COUNT+=1
    exit /b 0
)
call :validate_target "!TARGET!"
if errorlevel 1 (
    set /a FAILED_COUNT+=1
    exit /b 0
)
set "PROBE_PATH=!LINK!"
call :probe_path
if /I "!PROBE_KIND!"=="MISSING" (
    if /I "%MODE%"=="CHECK" (
        echo [MISSING] Link would be created: !LINK!  -^>  !TARGET!
        exit /b 0
    )
    rem Refuse to create missing parents. This avoids mkdir following a
    rem reparse point between validation and the link operation.
    for %%I in ("!LINK!\..") do set "LINK_PARENT=%%~fI"
    set "PROBE_PATH=!LINK_PARENT!"
    call :probe_path
    if /I not "!PROBE_KIND!"=="DIR" (
        echo [FAIL] Link parent must already be an ordinary directory: !LINK_PARENT!
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    call :validate_scope "!LINK!" "!TARGET!"
    if errorlevel 1 (
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    set "PROBE_PATH=!LINK!"
    call :probe_path
    if /I not "!PROBE_KIND!"=="MISSING" (
        echo [FAIL] Link appeared during repair; it was not overwritten: !LINK!
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    mklink /J "!LINK!" "!TARGET!" >nul 2>&1
    if errorlevel 1 (
        echo [FAIL] Junction creation failed: !LINK!
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    call :validate_scope "!LINK!" "!TARGET!"
    if errorlevel 1 (
        echo [FAIL] Post-create scope/race validation failed: !LINK!
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    call :validate_target "!TARGET!"
    if errorlevel 1 (
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    call :verify_junction_target "!LINK!" "!TARGET!"
    if errorlevel 1 (
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    echo [LINK] !LINK!  -^>  !TARGET!
    set /a CREATED_COUNT+=1
    exit /b 0
)
if /I "!PROBE_KIND!"=="JUNCTION" (
    call :validate_scope "!LINK!" "!TARGET!"
    if errorlevel 1 (
        set /a FAILED_COUNT+=1
        exit /b 0
    )
    call :verify_junction_target "!LINK!" "!TARGET!"
    if errorlevel 1 set /a FAILED_COUNT+=1
    exit /b 0
)
if /I "!PROBE_KIND!"=="UNSAFE_REPARSE" (
    echo [FAIL] Existing reparse point is not an approved junction: !LINK!
    set /a FAILED_COUNT+=1
    exit /b 0
)
if /I "!PROBE_KIND!"=="DIR" (
    echo [KEEP] Existing real path was not modified: !LINK!
    set /a SKIPPED_COUNT+=1
    exit /b 0
)
echo [FAIL] Existing link path is not a directory: !LINK!
set /a FAILED_COUNT+=1
exit /b 0

:validate_scope
set "SCOPE_LINK=%~1"
set "SCOPE_TARGET=%~2"
set "SCOPE_REPO=%REPO_ROOT%"
set "SCOPE_LEGACY=%LEGACY_ROOT%"
set "SCOPE_RESULT="
for /f "delims=" %%A in ('powershell.exe -NoLogo -NoProfile -Command "$repo=[Environment]::GetEnvironmentVariable('SCOPE_REPO'); $legacy=[Environment]::GetEnvironmentVariable('SCOPE_LEGACY'); $link=[Environment]::GetEnvironmentVariable('SCOPE_LINK'); $target=[Environment]::GetEnvironmentVariable('SCOPE_TARGET'); function Full([string]$p){try{$f=[IO.Path]::GetFullPath($p); if($f.Length -gt 3){$f=$f.TrimEnd([char]92)}; return $f}catch{return $null}}; function Under([string]$p,[string]$root){$f=Full $p; $r=Full $root; return ($f -and $r -and ($f -ieq $r -or $f.StartsWith($r+([char]92),[StringComparison]::OrdinalIgnoreCase)))}; function AncestorSafe([string]$p){$cursor=Full $p; if([string]::IsNullOrWhiteSpace($cursor)){return $false}; while($true){$i=Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue; if($i -and (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){return $false}; $parent=[IO.Directory]::GetParent($cursor); if($null -eq $parent -or $parent.FullName -ieq $cursor){break}; $cursor=$parent.FullName}; return $true}; $r=Full $repo; $l=Full $legacy; $x=Full $link; $t=Full $target; if(-not $r -or -not $l -or -not $x -or -not $t){Write-Output 'FAIL|invalid path'; exit 1}; if(-not (Under $t $r)){Write-Output 'FAIL|target is outside repository root'; exit 1}; if(-not (AncestorSafe $r)){Write-Output 'FAIL|repository root or ancestor is a reparse point'; exit 1}; if(-not (AncestorSafe $t)){Write-Output 'FAIL|target ancestor is a reparse point'; exit 1}; $ti=Get-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue; if($ti -and (($ti.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){Write-Output 'FAIL|target must be a physical directory'; exit 1}; if($x -ieq $t){Write-Output 'FAIL|link and target would form a cycle'; exit 1}; if($x -ieq $l){$parent=[IO.Directory]::GetParent($x); if($null -eq $parent -or -not (AncestorSafe $parent.FullName)){Write-Output 'FAIL|legacy link parent has a reparse ancestor'; exit 1}; $pi=Get-Item -LiteralPath $parent.FullName -Force -ErrorAction SilentlyContinue; if(-not $pi -or -not $pi.PSIsContainer -or (($pi.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){Write-Output 'FAIL|legacy link parent must be an ordinary directory'; exit 1}} elseif(Under $x $r){$parent=[IO.Directory]::GetParent($x); if($null -eq $parent -or -not (AncestorSafe $parent.FullName)){Write-Output 'FAIL|link parent is outside or has a reparse ancestor'; exit 1}; $pi=Get-Item -LiteralPath $parent.FullName -Force -ErrorAction SilentlyContinue; if($pi -and (($pi.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){Write-Output 'FAIL|link parent is a reparse point'; exit 1}} else {Write-Output 'FAIL|link is outside approved scope'; exit 1}; Write-Output 'OK'"') do set "SCOPE_RESULT=%%A"
if /I not "!SCOPE_RESULT!"=="OK" (
    echo [FAIL] !SCOPE_RESULT!  link=!SCOPE_LINK! target=!SCOPE_TARGET!
    exit /b 1
)
exit /b 0

:validate_target
set "TARGET_CHECK=%~1"
set "TARGET_RESULT="
for /f "delims=" %%A in ('powershell.exe -NoLogo -NoProfile -Command "$p=[Environment]::GetEnvironmentVariable('TARGET_CHECK'); $i=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; if(-not $i -or -not $i.PSIsContainer){Write-Output 'FAIL|target is missing or not a directory'; exit 1}; if(($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){Write-Output 'FAIL|target is a reparse point'; exit 1}; Write-Output 'OK'"') do set "TARGET_RESULT=%%A"
if /I not "!TARGET_RESULT!"=="OK" (
    echo [FAIL] !TARGET_RESULT!  target=!TARGET_CHECK!
    exit /b 1
)
exit /b 0

:probe_path
set "PROBE_KIND="
set "PROBE_TARGET="
for /f "tokens=1,* delims=|" %%A in ('powershell.exe -NoLogo -NoProfile -Command "$p=Get-Item -LiteralPath $env:PROBE_PATH -Force -ErrorAction SilentlyContinue; if(-not $p){'MISSING'} elseif(($p.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){if($p.PSIsContainer -and ([string]$p.LinkType -ieq 'Junction')){$ts=@($p.Target); if($ts.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace([string]$ts[0])){'JUNCTION|' + [string]$ts[0]} else {'UNSAFE_REPARSE'}} else {'UNSAFE_REPARSE'}} elseif($p.PSIsContainer){'DIR'} else {'FILE'}"') do (
    set "PROBE_KIND=%%A"
    set "PROBE_TARGET=%%B"
)
if not defined PROBE_KIND set "PROBE_KIND=UNKNOWN"
exit /b 0

:verify_junction_target
set "VERIFY_LINK=%~1"
set "VERIFY_TARGET=%~2"
set "VERIFY_RESULT="
for /f "delims=" %%A in ('powershell.exe -NoLogo -NoProfile -Command "$link=[Environment]::GetEnvironmentVariable('VERIFY_LINK'); $expected=[Environment]::GetEnvironmentVariable('VERIFY_TARGET'); $i=Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue; if(-not $i -or -not $i.PSIsContainer -or (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) -or ([string]$i.LinkType -ine 'Junction')){Write-Output 'FAIL|existing path is not a junction'; exit 1}; $raw=@($i.Target); if($raw.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$raw[0])){Write-Output 'FAIL|junction target is not exactly one path'; exit 1}; $actual=[string]$raw[0]; if(-not [IO.Path]::IsPathRooted($actual)){$actual=Join-Path $i.DirectoryName $actual}; try{$actual=[IO.Path]::GetFullPath($actual); $want=[IO.Path]::GetFullPath($expected)}catch{Write-Output 'FAIL|junction target cannot be normalized'; exit 1}; if($actual.Length -gt 3){$actual=$actual.TrimEnd([char]92)}; if($want.Length -gt 3){$want=$want.TrimEnd([char]92)}; if($actual -ine $want){Write-Output ('FAIL|junction target mismatch expected=' + $want + ' actual=' + $actual); exit 1}; Write-Output 'OK'"') do set "VERIFY_RESULT=%%A"
if /I not "!VERIFY_RESULT!"=="OK" (
    echo [FAIL] !VERIFY_RESULT!  link=!VERIFY_LINK! target=!VERIFY_TARGET!
    exit /b 1
)
echo [OK] Existing junction target verified: !VERIFY_LINK!
exit /b 0
