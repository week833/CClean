[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = 'D:\stock\GitHub'
$helper = Join-Path $root 'scripts\setup\assert_fixed_install_root.ps1'
$tempRoots = New-Object 'System.Collections.Generic.List[string]'

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-TestRoot {
    $path = Join-Path $env:TEMP ('stock-entrypoint-binding-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $tempRoots.Add($path)
    return $path
}

function Remove-TestRoot([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        [IO.Directory]::Delete($Path, $true)
    }
}

function Invoke-Helper([string]$Name, [string]$TestRoot = $null) {
    $oldMode = $env:STOCK_SETUP_TEST_MODE
    try {
        $env:STOCK_SETUP_TEST_MODE = '1'
        if ($TestRoot) {
            $output = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $helper -TestRoot $TestRoot 2>&1 | ForEach-Object { [string]$_ })
        }
        else {
            $output = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $helper 2>&1 | ForEach-Object { [string]$_ })
        }
        $code = $LASTEXITCODE
    }
    finally {
        if ($null -eq $oldMode) { Remove-Item Env:STOCK_SETUP_TEST_MODE -ErrorAction SilentlyContinue }
        else { $env:STOCK_SETUP_TEST_MODE = $oldMode }
    }
    Write-Host ("{0}: exit={1}" -f $Name, $code)
    $output | ForEach-Object { Write-Host $_ }
    return [pscustomobject]@{ Code = $code; Output = ($output -join "`n") }
}

function Snapshot([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @('MISSING') }
    return @(
        Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)|$($_.Attributes)" } |
            Sort-Object
    )
}

function Invoke-WrongCallerCopy([string]$Name, [string]$Arguments) {
    $fixture = New-TestRoot
    $copy = Join-Path $fixture $Name
    Copy-Item -LiteralPath (Join-Path $root $Name) -Destination $copy
    $before = @(Snapshot $fixture)
    $oldNoPause = $env:STOCK_TOOLKIT_NO_PAUSE
    try {
        $env:STOCK_TOOLKIT_NO_PAUSE = '1'
        $process = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/c', ('call "{0}" {1}' -f $copy, $Arguments)) -PassThru -WindowStyle Hidden
        if (-not $process.WaitForExit(60000)) {
            try { $process.Kill() } catch { }
            throw "Wrong caller copy timed out after 60 seconds: $Name"
        }
        $code = $process.ExitCode
    }
    finally {
        if ($null -eq $oldNoPause) { Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue }
        else { $env:STOCK_TOOLKIT_NO_PAUSE = $oldNoPause }
    }
    $after = @(Snapshot $fixture)
    Assert ($code -eq 0) ("Wrong caller copy failed: {0} exit={1}" -f $Name, $code)
    Assert (@(Compare-Object $before $after).Count -eq 0) ("Wrong caller copy wrote local files: {0}" -f $Name)
    Write-Host ("wrong_caller_copy={0}: local_snapshot_unchanged PASS" -f $Name)
}

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Invoke-FixtureWrapper([Parameter(Mandatory)][string]$WrapperPath, [string]$Arguments = '', [hashtable]$Environment = @{}) {
    $oldNoPause = $env:STOCK_TOOLKIT_NO_PAUSE
    $oldHelperRc = $env:STOCK_TEST_HELPER_RC
    $oldCoreRc = $env:STOCK_TEST_CORE_RC
    try {
        $env:STOCK_TOOLKIT_NO_PAUSE = '1'
        $env:STOCK_TEST_HELPER_RC = if ($Environment.ContainsKey('STOCK_TEST_HELPER_RC')) { [string]$Environment.STOCK_TEST_HELPER_RC } else { '' }
        $env:STOCK_TEST_CORE_RC = if ($Environment.ContainsKey('STOCK_TEST_CORE_RC')) { [string]$Environment.STOCK_TEST_CORE_RC } else { '' }
        $output = @(& $env:ComSpec /d /c ('call "{0}" {1}' -f $WrapperPath, $Arguments) 2>&1 | ForEach-Object { [string]$_ })
        $code = $LASTEXITCODE
    }
    finally {
        if ($null -eq $oldNoPause) { Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue } else { $env:STOCK_TOOLKIT_NO_PAUSE = $oldNoPause }
        if ($null -eq $oldHelperRc) { Remove-Item Env:STOCK_TEST_HELPER_RC -ErrorAction SilentlyContinue } else { $env:STOCK_TEST_HELPER_RC = $oldHelperRc }
        if ($null -eq $oldCoreRc) { Remove-Item Env:STOCK_TEST_CORE_RC -ErrorAction SilentlyContinue } else { $env:STOCK_TEST_CORE_RC = $oldCoreRc }
    }
    return [pscustomobject]@{ Code = $code; Output = ($output -join "`n") }
}

function New-FullInstallerFixture([Parameter(Mandatory)][string]$Parent, [Parameter(Mandatory)][string]$Name) {
    $fixture = Join-Path $Parent $Name
    $install = Join-Path $fixture 'install'
    $package = Join-Path $fixture 'package'
    New-Item -ItemType Directory -Path (Join-Path $install 'scripts\setup') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $package 'scripts\setup') -Force | Out-Null
    $wrapperText = Get-Content -LiteralPath (Join-Path $root 'INSTALL_D_STOCK_ENV_FULL.cmd') -Raw
    $wrapperText = $wrapperText.Replace('D:\stock\GitHub', $install)
    $wrapperPath = Join-Path $package 'INSTALL_D_STOCK_ENV_FULL.cmd'
    [IO.File]::WriteAllText($wrapperPath, $wrapperText, [Text.Encoding]::ASCII)
    $helperPath = Join-Path $install 'scripts\setup\assert_fixed_install_root.ps1'
    $corePath = Join-Path $install 'scripts\setup\install_d_stock_env.ps1'
    Write-Utf8NoBom $helperPath "if(`$env:STOCK_TEST_HELPER_RC){exit [int]`$env:STOCK_TEST_HELPER_RC}; Write-Host 'Fixed install root verified'; exit 0"
    Write-Utf8NoBom $corePath "if(`$env:STOCK_TEST_CORE_RC){exit [int]`$env:STOCK_TEST_CORE_RC}; Write-Host '[OK] Preflight completed without writes.'; exit 0"
    $localCore = Join-Path $package 'scripts\setup\install_d_stock_env.ps1'
    Copy-Item -LiteralPath $corePath -Destination $localCore -Force
    return [pscustomobject]@{ Fixture = $fixture; Install = $install; Package = $package; Wrapper = $wrapperPath; Helper = $helperPath; Core = $corePath }
}

function Invoke-FullInstallerFixtureCases {
    $parent = New-TestRoot
    $fixture = New-FullInstallerFixture -Parent $parent -Name 'fixed'
    $helperFailure = Invoke-FixtureWrapper -WrapperPath $fixture.Wrapper -Arguments '/CHECK' -Environment @{ STOCK_TEST_HELPER_RC = '7' }
    Assert ($helperFailure.Code -eq 7) ("Full wrapper must propagate helper failure; got {0}`n{1}" -f $helperFailure.Code, $helperFailure.Output)
    $coreFailure = Invoke-FixtureWrapper -WrapperPath $fixture.Wrapper -Arguments '/PREFLIGHT' -Environment @{ STOCK_TEST_CORE_RC = '9' }
    Assert ($coreFailure.Code -eq 9) ("Full wrapper must propagate core preflight failure; got {0}`n{1}" -f $coreFailure.Code, $coreFailure.Output)
    Write-Host 'full_wrapper_helper_core_nonzero: helper=7 core=9 propagated PASS'

    $empty = New-FullInstallerFixture -Parent $parent -Name 'empty'
    Remove-Item -LiteralPath $empty.Install -Recurse -Force
    New-Item -ItemType Directory -Path $empty.Install -Force | Out-Null
    $emptyResult = Invoke-FixtureWrapper -WrapperPath $empty.Wrapper -Arguments '/PREFLIGHT'
    Assert ($emptyResult.Code -eq 0) ("Empty fixed root should take bootstrap preflight path; got {0}`n{1}" -f $emptyResult.Code, $emptyResult.Output)
    New-Item -ItemType File -Path (Join-Path $empty.Install 'unmanaged.fixture') -Force | Out-Null
    $nonEmptyResult = Invoke-FixtureWrapper -WrapperPath $empty.Wrapper -Arguments '/PREFLIGHT'
    Assert ($nonEmptyResult.Code -eq 2) ("Non-empty root without helper must fail closed with exit 2; got {0}`n{1}" -f $nonEmptyResult.Code, $nonEmptyResult.Output)
    Write-Host 'full_wrapper_empty_root_bootstrap: empty=0 nonempty=2 PASS'
}

function Assert-WrapperStaticBinding {
    $wrappers = @(
        'INSTALL_D_STOCK_ENV_FULL.cmd', 'DOWNLOAD_STOCK_SOURCES.cmd',
        'DOWNLOAD_LEGACY_SOURCES.cmd', 'CONFIGURE_WINDOWS_ENV.cmd',
        'REPAIR_STOCK_PATHS.cmd', 'OPEN_STOCK_TERMINAL.cmd',
        'VERIFY_STOCK_ENV.cmd', 'RUN_STOCK_PYTHON.cmd'
    )
    foreach ($name in $wrappers) {
        $text = Get-Content -LiteralPath (Join-Path $root $name) -Raw
        Assert ($text.Contains('assert_fixed_install_root.ps1')) "Wrapper is missing fixed-root helper: $name"
        Assert ($text.Contains('FIXED_ROOT=D:\stock\GitHub')) "Wrapper is missing fixed root: $name"
        Assert ($text.Contains('%FIXED_ROOT%')) "Wrapper is missing fixed-root target expansion: $name"
        if ($name -ne 'INSTALL_D_STOCK_ENV_FULL.cmd') {
            Assert (-not $text.Contains('%~dp0')) "Operational wrapper derives target from caller %%~dp0: $name"
        }
    }
    Write-Host ("wrapper_static_fixed_root_binding={0}: PASS" -f $wrappers.Count)
}

try {
    Assert (Test-Path -LiteralPath $helper -PathType Leaf) "Fixed-root helper missing: $helper"
    Assert-WrapperStaticBinding
    $verifyWrapper = Join-Path $root 'VERIFY_STOCK_ENV.cmd'
    $verifyText = Get-Content -LiteralPath $verifyWrapper -Raw
    Assert ($verifyText.Contains('assert_fixed_install_root.ps1')) 'VERIFY_STOCK_ENV.cmd is missing the fixed-root identity check.'
    Assert ($verifyText.Contains('FIXED_ROOT=D:\stock\GitHub')) 'VERIFY_STOCK_ENV.cmd is missing the fixed root binding.'
    Assert ($verifyText.Contains('%FIXED_ROOT%')) 'VERIFY_STOCK_ENV.cmd does not call through the fixed-root variable.'
    Write-Host 'verify_wrapper_fixed_root_static: PASS'
    $fixed = Invoke-Helper -Name 'fixed-root'
    Assert ($fixed.Code -eq 0) 'Current fixed root should verify.'
    Assert ($fixed.Output -match 'Fixed install root verified') 'Fixed root success evidence is missing.'

    $valid = New-TestRoot
    & git.exe init $valid --quiet
    & git.exe -C $valid remote add origin https://github.com/week833/stock.git
    $validResult = Invoke-Helper -Name 'test-root-valid-origin' -TestRoot $valid
    Assert ($validResult.Code -eq 0) 'Valid TestRoot origin should verify.'

    $wrong = New-TestRoot
    & git.exe init $wrong --quiet
    & git.exe -C $wrong remote add origin https://example.invalid/not-stock.git
    $wrongResult = Invoke-Helper -Name 'wrong-origin' -TestRoot $wrong
    Assert ($wrongResult.Code -eq 2) 'Wrong origin must fail closed with exit 2.'

    $missing = Join-Path $env:TEMP ('stock-entrypoint-missing-' + [guid]::NewGuid().ToString('N'))
    $missingResult = Invoke-Helper -Name 'missing-root' -TestRoot $missing
    Assert ($missingResult.Code -eq 2) 'Missing root must fail closed with exit 2.'

    $gitFileRoot = New-TestRoot
    [IO.File]::WriteAllText((Join-Path $gitFileRoot '.git'), "gitdir: D:\stock\outside`r`n")
    $gitFileResult = Invoke-Helper -Name 'gitdir-escape' -TestRoot $gitFileRoot
    Assert ($gitFileResult.Code -eq 2) 'External gitdir file must fail closed with exit 2.'

    $junctionTarget = New-TestRoot
    $junctionRoot = Join-Path $env:TEMP ('stock-entrypoint-junction-' + [guid]::NewGuid().ToString('N'))
    $junctionReady = $false
    try {
        try {
            New-Item -ItemType Junction -Path $junctionRoot -Target $junctionTarget -Force -ErrorAction Stop | Out-Null
            $junctionReady = $true
        }
        catch {
            Write-Host ("[SKIP] root reparse helper case unavailable: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
        }
        if ($junctionReady) {
            $junctionResult = Invoke-Helper -Name 'reparse-root' -TestRoot $junctionRoot
            Assert ($junctionResult.Code -eq 2) 'Reparse root must fail closed with exit 2.'
            Assert (Test-Path -LiteralPath $junctionTarget -PathType Container) 'Reparse target was unexpectedly changed.'
        }
    }
    finally {
        if ($junctionReady -and (Test-Path -LiteralPath $junctionRoot)) { Remove-Item -LiteralPath $junctionRoot -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $junctionTarget) { Remove-TestRoot $junctionTarget }
    }

    Invoke-FullInstallerFixtureCases
    Invoke-WrongCallerCopy -Name 'INSTALL_D_STOCK_ENV_FULL.cmd' -Arguments '/CHECK'

    Write-Host 'entrypoint root binding: PASS' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ("entrypoint root binding: FAIL - {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    foreach ($path in $tempRoots) {
        if (Test-Path -LiteralPath $path) { Remove-TestRoot $path }
    }
}
