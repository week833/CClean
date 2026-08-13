[CmdletBinding()]
param(
    [switch]$CiMode,
    [switch]$SkipOperational
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$venv = Join-Path $root '.venv'
$venvPython = Join-Path $venv 'Scripts\python.exe'
$git = $null
$oldNoPause = $env:STOCK_TOOLKIT_NO_PAUSE
$env:STOCK_TOOLKIT_NO_PAUSE = '1'

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Test-UserPathEntry([AllowNull()][string]$UserPath, [Parameter(Mandatory)][string]$Target) {
    $canonicalTarget = $Target.Trim().TrimEnd('\')
    $entries = @($UserPath -split ';' |
        ForEach-Object { $_.Trim().TrimEnd('\') } |
        Where-Object { $_ -ne '' })
    foreach ($entry in $entries) {
        if ([string]::Equals($entry, $canonicalTarget, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Invoke-CmdCheck([string]$Name, [string]$Command, [int]$Expected = 0) {
    & cmd.exe /d /c $Command *> $null
    $code = $LASTEXITCODE
    Write-Host ("{0}: exit={1}" -f $Name, $code)
    Assert ($code -eq $Expected) ("{0} expected exit {1}, got {2}" -f $Name, $Expected, $code)
}

function Invoke-CmdCapture([string]$Name, [string]$Command, [int]$Expected = 0) {
    $output = @(& cmd.exe /d /c $Command 2>&1 | ForEach-Object { [string]$_ })
    $code = $LASTEXITCODE
    Write-Host ("{0}: exit={1}" -f $Name, $code)
    Assert ($code -eq $Expected) ("{0} expected exit {1}, got {2}`n{3}" -f $Name, $Expected, $code, ($output -join "`n"))
    return ($output -join "`n")
}

function Get-RepoCount {
    $categories = @(
        'taiwan_market_data', 'global_market_data',
        'machine_learning_forecasting', 'backtesting_engines',
        'quant_portfolio_risk'
    )
    $count = 0
    foreach ($category in $categories) {
        $path = Join-Path $root (Join-Path 'repos' $category)
        if (Test-Path -LiteralPath $path -PathType Container) {
            $count += @((Get-ChildItem -LiteralPath $path -Directory -Force -ErrorAction SilentlyContinue)).Count
        }
    }
    return $count
}

function Get-JunctionCount {
    return @(
        Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction SilentlyContinue |
            Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }
    ).Count
}

function Get-Snapshot {
    $names = @('STOCK_HOME', 'STOCK_REPO', 'STOCK_VENV', 'STOCK_PYTHON', 'STOCK_EXTERNAL_REPOS')
    $vars = foreach ($name in $names) {
        '{0}={1}' -f $name, [Environment]::GetEnvironmentVariable($name, 'User')
    }
    [pscustomobject][ordered]@{
        GitStatus = ((& $git -C $root status --porcelain --untracked-files=all) -join "`n")
        UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        UserVars = ($vars -join "`n")
        VenvMtime = if (Test-Path -LiteralPath $venv) { (Get-Item -LiteralPath $venv).LastWriteTimeUtc.Ticks } else { 0 }
        RepoCount = Get-RepoCount
        JunctionCount = Get-JunctionCount
    }
}

function Invoke-CiTempFixture([Parameter(Mandatory)][string]$HelperPath) {
    $fixture = Join-Path $env:TEMP ('stock-installer-ci-fixture-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    try {
        $gitCommand = Get-Command git.exe -ErrorAction Stop
        & $gitCommand.Source init $fixture --quiet
        Assert ($LASTEXITCODE -eq 0) 'CI TEMP fixture git init failed.'
        & $gitCommand.Source -C $fixture remote add origin 'https://github.com/week833/stock.git'
        Assert ($LASTEXITCODE -eq 0) 'CI TEMP fixture git remote setup failed.'

        $oldTestMode = $env:STOCK_SETUP_TEST_MODE
        $env:STOCK_SETUP_TEST_MODE = '1'
        try {
            $output = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $HelperPath -TestRoot $fixture 2>&1 | ForEach-Object { [string]$_ })
            $code = $LASTEXITCODE
        }
        finally {
            if ($null -eq $oldTestMode) { Remove-Item Env:STOCK_SETUP_TEST_MODE -ErrorAction SilentlyContinue }
            else { $env:STOCK_SETUP_TEST_MODE = $oldTestMode }
        }
        Assert ($code -eq 0) ("CI TEMP fixed-root helper fixture failed with exit {0}: {1}" -f $code, ($output -join "`n"))
        Write-Host 'ci_temp_fixed_root_fixture: PASS'
    }
    finally {
        if (Test-Path -LiteralPath $fixture) { [IO.Directory]::Delete($fixture, $true) }
    }
}

try {
    if (-not $CiMode) {
        Assert ((Split-Path -Leaf $root) -eq 'GitHub') "Unexpected integration root: $root"
    }
    Assert ((Test-Path -LiteralPath (Join-Path $root 'STOCK_SETUP_MANAGER.cmd')) -and
        (Test-Path -LiteralPath (Join-Path $root 'VERIFY_STOCK_ENV.cmd'))) 'Required wrappers are missing.'

    $manager = Get-Content -LiteralPath (Join-Path $root 'STOCK_SETUP_MANAGER.cmd') -Raw
    $managerTargets = @(
        'INSTALL_D_STOCK_ENV.cmd', 'INSTALL_D_STOCK_ENV_FULL.cmd',
        'DOWNLOAD_STOCK_SOURCES.cmd', 'DOWNLOAD_LEGACY_SOURCES.cmd',
        'REPAIR_STOCK_PATHS.cmd', 'CONFIGURE_WINDOWS_ENV.cmd',
        'VERIFY_STOCK_ENV.cmd', 'OPEN_STOCK_TERMINAL.cmd'
    )
    foreach ($target in $managerTargets) {
        Assert ($manager.Contains($target)) "Manager target is not wired: $target"
        $targetExists = (Test-Path -LiteralPath (Join-Path $root $target) -PathType Leaf -ErrorAction SilentlyContinue) -or
            (Test-Path -LiteralPath (Join-Path $root ('scripts\compat\' + $target)) -PathType Leaf -ErrorAction SilentlyContinue) -or
            (Test-Path -LiteralPath (Join-Path $root ('scripts\sources\' + $target)) -PathType Leaf -ErrorAction SilentlyContinue)
        Assert $targetExists "Manager target file missing: $target"
    }
    Assert ($manager.Contains('FIXED_ROOT=D:\stock\GitHub')) 'Manager must bind operational options to the fixed root.'
    Assert ($manager.Contains('call :require_fixed_root')) 'Manager must verify fixed-root identity before operational options.'
    Write-Host ('manager_targets={0}: PASS' -f $managerTargets.Count)

    $helper = Join-Path $root 'scripts\setup\assert_fixed_install_root.ps1'
    Assert (Test-Path -LiteralPath $helper -PathType Leaf) 'Fixed-root identity helper is missing.'
    $rootBindingWrappers = @(
        'INSTALL_D_STOCK_ENV_FULL.cmd', 'DOWNLOAD_STOCK_SOURCES.cmd',
        'DOWNLOAD_LEGACY_SOURCES.cmd', 'CONFIGURE_WINDOWS_ENV.cmd',
        'REPAIR_STOCK_PATHS.cmd', 'OPEN_STOCK_TERMINAL.cmd',
        'VERIFY_STOCK_ENV.cmd', 'RUN_STOCK_PYTHON.cmd', 'install_tw_stock_ai_env.cmd'
    )
    foreach ($wrapper in $rootBindingWrappers) {
        $wrapperPath = Join-Path $root $wrapper
        $wrapperText = Get-Content -LiteralPath $wrapperPath -Raw
        Assert ($wrapperText.Contains('assert_fixed_install_root.ps1')) "Wrapper is missing fixed-root identity check: $wrapper"
        Assert ($wrapperText.Contains('FIXED_ROOT=D:\stock\GitHub')) "Wrapper is missing the fixed root binding: $wrapper"
        Assert ($wrapperText.Contains('%FIXED_ROOT%')) "Wrapper does not call through the fixed-root variable: $wrapper"
        if ($wrapper -ne 'INSTALL_D_STOCK_ENV_FULL.cmd') {
            Assert (-not $wrapperText.Contains('%~dp0')) "Operational wrapper must not derive a target from caller %%~dp0: $wrapper"
        }
    }
    $fullText = Get-Content -LiteralPath (Join-Path $root 'INSTALL_D_STOCK_ENV_FULL.cmd') -Raw
    Assert ($fullText.Contains('call "%FIXED_ROOT%\scripts\sources\clone_stock_analysis_repos.cmd"')) 'Full installer must call fixed primary source script.'
    Assert ($fullText.Contains('call "%FIXED_ROOT%\scripts\compat\verify_stock_environment.cmd"')) 'Full installer must call fixed verification script.'
    Assert (-not $fullText.Contains('call "%~dp0scripts\sources')) 'Full installer must not call source scripts from the caller copy.'
    Write-Host ('fixed_root_wrappers={0}: PASS' -f $rootBindingWrappers.Count)

    $repairStart = [regex]::Match($manager, '(?m)^:repair(?:\r?\n|$)').Index
    $repairEnd = [regex]::Match($manager, '(?m)^:configure(?:\r?\n|$)').Index
    Assert (($repairStart -ge 0) -and ($repairEnd -gt $repairStart)) 'Manager repair block is missing or malformed.'
    $repairBlock = $manager.Substring($repairStart, $repairEnd - $repairStart)
    Assert ($repairBlock.Contains('REPAIR_STOCK_PATHS.cmd" --check')) 'Manager repair must run root --check first.'
    Assert ($repairBlock.Contains('REPAIR_STOCK_PATHS.cmd" --apply --confirm')) 'Manager repair must gate --apply --confirm.'
    Assert ($repairBlock.Contains('choice /C YN')) 'Manager repair must require an explicit Y/N choice.'
    Assert ($repairBlock.Contains('if errorlevel 1 goto :repair_check_failed')) 'Manager repair must stop when --check fails.'
    Assert ($repairBlock.Contains('if errorlevel 2 goto :repair_declined')) 'Manager repair N path must return without apply.'
    Assert ($repairBlock.IndexOf('REPAIR_STOCK_PATHS.cmd" --check') -lt $repairBlock.IndexOf('choice /C YN')) 'Manager repair must check before prompting for apply.'
    Write-Host 'manager_repair_check_y_apply_gate: PASS'

    $compatInstaller = Get-Content -LiteralPath (Join-Path $root 'scripts\setup\install_tw_stock_ai_env.cmd') -Raw
    Assert ($compatInstaller.Contains('repair_legacy_paths.cmd" --check')) 'Core installer step 7 must use read-only --check.'
    Assert (-not [regex]::IsMatch($compatInstaller, '(?im)^\s*call\s+.*repair_legacy_paths\.cmd"\s*$')) 'Core installer must not invoke repair without arguments.'
    Assert (-not $compatInstaller.Contains('--apply')) 'Core installer must not apply legacy path repairs.'
    Assert ($compatInstaller.Contains('no junctions will be created')) 'Core installer must state that step 7 is read-only.'
    Assert ($compatInstaller.Contains('Legacy path check failed')) 'Core installer must report a failed read-only path check.'
    Write-Host 'compat_installer_repair_check_only: PASS'

    $dangerous = @('git reset --hard HEAD', 'git config --global', 'reg add', 'checkout -f')
    $scanFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\setup') -File | Where-Object { $_.Extension -in @('.ps1', '.cmd') }
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\sources') -File | Where-Object { $_.Extension -in @('.ps1', '.cmd') }
        Get-ChildItem -LiteralPath $root -File | Where-Object { $_.Extension -ieq '.cmd' }
    )
    foreach ($file in $scanFiles) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($needle in $dangerous) {
            Assert (-not $text.Contains($needle)) "Dangerous string '$needle' remains in $($file.FullName)"
        }
    }
    Write-Host ('dangerous_strings=0 scanned_files={0}: PASS' -f $scanFiles.Count)

    $cmdFiles = @(
        Get-ChildItem -LiteralPath $root -File | Where-Object { $_.Extension -ieq '.cmd' }
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\setup') -File | Where-Object { $_.Extension -ieq '.cmd' }
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\sources') -File | Where-Object { $_.Extension -ieq '.cmd' }
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\compat') -File | Where-Object { $_.Extension -ieq '.cmd' }
    ) | Sort-Object FullName -Unique
    foreach ($file in $cmdFiles) {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        Assert (-not @($bytes | Where-Object { $_ -gt 127 }).Count) "CMD is not ASCII: $($file.FullName)"
        $text = [Text.Encoding]::ASCII.GetString($bytes)
        Assert (-not [regex]::IsMatch($text, "(?<!`r)`n")) "CMD is not CRLF: $($file.FullName)"
    }
    Write-Host ('cmd_ascii_crlf={0}: PASS' -f $cmdFiles.Count)

    $psFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\setup') -File | Where-Object { $_.Extension -ieq '.ps1' }
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\sources') -File | Where-Object { $_.Extension -ieq '.ps1' }
        Get-ChildItem -LiteralPath (Join-Path $root 'scripts\compat') -File | Where-Object { $_.Extension -ieq '.ps1' }
    )
    foreach ($file in $psFiles) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        Assert ($errors.Count -eq 0) "PowerShell parser errors in $($file.FullName): $($errors | Out-String)"
    }
    Write-Host ('powershell_parse={0}: PASS' -f $psFiles.Count)

    Assert (Test-UserPathEntry 'D:\stock\GitHub;D:\stock\GitHub\.venv\Scripts;D:\stock\GitHub\scripts' 'D:\stock\GitHub\.venv\Scripts') 'User PATH canonical check rejected an exact managed entry.'
    Assert (Test-UserPathEntry 'D:\STOCK\github\.VENV\Scripts\;D:\stock\GitHub\scripts' 'D:\stock\GitHub\.venv\Scripts') 'User PATH canonical check rejected case/trailing-slash variants.'
    Assert (-not (Test-UserPathEntry 'D:\stock\GitHub;D:\stock\GitHub\scripts' 'D:\stock\GitHub\.venv\Scripts')) 'User PATH canonical check accepted a missing managed entry.'
    Assert (-not (Test-UserPathEntry '' 'D:\stock\GitHub\.venv\Scripts')) 'User PATH canonical check accepted an empty PATH.'
    Write-Host 'user_path_canonical_regression=0/1/N, case, trailing-slash: PASS'

    if ($CiMode) {
        Invoke-CiTempFixture -HelperPath $helper
        Write-Host 'installer integration CI mode: PASS' -ForegroundColor Green
        exit 0
    }

    $git = (Get-Command git.exe -ErrorAction Stop).Source
    $before = Get-Snapshot
    if (-not $SkipOperational) {
        Invoke-CmdCheck 'assert_fixed_install_root.ps1' "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$helper`""
        Invoke-CmdCheck 'INSTALL_D_STOCK_ENV.cmd /CHECK' "`"$root\INSTALL_D_STOCK_ENV.cmd`" /CHECK"
        $preflightOutput = Invoke-CmdCapture 'INSTALL_D_STOCK_ENV.cmd /PREFLIGHT' "`"$root\INSTALL_D_STOCK_ENV.cmd`" /PREFLIGHT"
        Assert ($preflightOutput.Contains('[OK] Preflight completed without writes.')) 'INSTALL_D_STOCK_ENV.cmd /PREFLIGHT did not expose the core preflight marker.'
        Invoke-CmdCheck 'INSTALL_D_STOCK_ENV.cmd /DRY-RUN' "`"$root\INSTALL_D_STOCK_ENV.cmd`" /DRY-RUN"
        Invoke-CmdCheck 'INSTALL_D_STOCK_ENV_FULL.cmd /CHECK' "`"$root\INSTALL_D_STOCK_ENV_FULL.cmd`" /CHECK"
        $fullPreflightOutput = Invoke-CmdCapture 'INSTALL_D_STOCK_ENV_FULL.cmd /PREFLIGHT' "`"$root\INSTALL_D_STOCK_ENV_FULL.cmd`" /PREFLIGHT"
        Assert ($fullPreflightOutput.Contains('[OK] Preflight completed without writes.')) 'INSTALL_D_STOCK_ENV_FULL.cmd /PREFLIGHT did not expose the core preflight marker.'
        Invoke-CmdCheck 'INSTALL_D_STOCK_ENV_FULL.cmd /DRY-RUN' "`"$root\INSTALL_D_STOCK_ENV_FULL.cmd`" /DRY-RUN"
        Invoke-CmdCheck 'INSTALL_D_STOCK_ENV_FULL.cmd unknown option' "`"$root\INSTALL_D_STOCK_ENV_FULL.cmd`" /UNSUPPORTED" 2
        Invoke-CmdCheck 'CONFIGURE_WINDOWS_ENV.cmd /PREFLIGHT' "`"$root\CONFIGURE_WINDOWS_ENV.cmd`" /PREFLIGHT"
        Invoke-CmdCheck 'CONFIGURE_WINDOWS_ENV.cmd /CHECK' "`"$root\CONFIGURE_WINDOWS_ENV.cmd`" /CHECK"
        Invoke-CmdCheck 'DOWNLOAD_STOCK_SOURCES.cmd --check' "`"$root\DOWNLOAD_STOCK_SOURCES.cmd`" --check"
        Invoke-CmdCheck 'DOWNLOAD_STOCK_SOURCES.cmd --dry-run' "`"$root\DOWNLOAD_STOCK_SOURCES.cmd`" --dry-run"
        Invoke-CmdCheck 'DOWNLOAD_LEGACY_SOURCES.cmd --check' "`"$root\DOWNLOAD_LEGACY_SOURCES.cmd`" --check"
        Invoke-CmdCheck 'DOWNLOAD_LEGACY_SOURCES.cmd --dry-run' "`"$root\DOWNLOAD_LEGACY_SOURCES.cmd`" --dry-run"
        Invoke-CmdCheck 'repair_legacy_paths.cmd --check' "`"$root\scripts\compat\repair_legacy_paths.cmd`" --check"
        $verifyOutput = Invoke-CmdCapture 'VERIFY_STOCK_ENV.cmd' "`"$root\VERIFY_STOCK_ENV.cmd`""
        $managedVenvText = '[OK] User PATH contains D:\stock\GitHub\.venv\Scripts'
        $missingVenvText = '[WARN] User PATH does not contain D:\stock\GitHub\.venv\Scripts'
        Assert ($verifyOutput.Contains($managedVenvText)) 'VERIFY_STOCK_ENV.cmd did not confirm the persisted managed venv PATH entry.'
        Assert (-not $verifyOutput.Contains($missingVenvText)) 'VERIFY_STOCK_ENV.cmd falsely warned about the persisted managed venv PATH entry.'
    }
    else {
        Write-Host 'normal integration: operational wrapper calls skipped; covered by independent production read-only commands.'
    }

    Assert (Test-Path -LiteralPath $venvPython -PathType Leaf) "Managed venv Python missing: $venvPython"
    & $venvPython --version *> $null
    Assert ($LASTEXITCODE -eq 0) 'Managed venv Python --version failed.'
    & $venvPython -m pip check *> $null
    Assert ($LASTEXITCODE -eq 0) 'Managed venv pip check failed.'
    $env:PYTHONDONTWRITEBYTECODE = '1'
    & $venvPython -c 'import FinMind, twstock, pandas, numpy, yfinance, requests, matplotlib, openpyxl' *> $null
    Assert ($LASTEXITCODE -eq 0) 'Managed venv core imports failed.'

    & cmd.exe /d /c "git -C `"$root`" diff --check >nul 2>nul"
    $rawDiffCode = $LASTEXITCODE
    if ($rawDiffCode -ne 0) { Write-Host 'git diff --check raw exit is nonzero because core.autocrlf emits CRLF advisory.' }
    & cmd.exe /d /c "git -C `"$root`" -c core.whitespace=cr-at-eol diff --check >nul 2>nul"
    Assert ($LASTEXITCODE -eq 0) 'git diff --check with CRLF policy failed.'
    Write-Host ("git_diff_check=normalized PASS; raw_exit={0} CRLF advisory={1}" -f $rawDiffCode, ($rawDiffCode -ne 0))

    $after = Get-Snapshot
    foreach ($property in @('GitStatus', 'UserPath', 'UserVars', 'VenvMtime', 'RepoCount', 'JunctionCount')) {
        Assert ([string]$before.$property -ceq [string]$after.$property) "Read-only check changed $property."
    }
    Write-Host ("snapshot_unchanged=GitStatus/UserPath/UserVars/.venv_mtime/RepoCount/JunctionCount; repos={0}; junctions={1}: PASS" -f $after.RepoCount, $after.JunctionCount)
    Write-Host 'installer integration: PASS'
    exit 0
}
catch {
    Write-Host ("installer integration: FAIL - {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    if ($null -eq $oldNoPause) { Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue }
    else { $env:STOCK_TOOLKIT_NO_PAUSE = $oldNoPause }
}
