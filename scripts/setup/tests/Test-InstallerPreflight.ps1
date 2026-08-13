[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$core = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\install_d_stock_env.ps1'))

try {
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $core -SelfTest | ForEach-Object { Write-Host $_ }
    $selfTestCode = $LASTEXITCODE
    if ($selfTestCode -ne 0) { throw "installer self-test failed with exit $selfTestCode" }
    Write-Host "path-merge-selftest: exit=$selfTestCode"
}
catch {
    Write-Host ("[ERROR] {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}

function New-TestRoot {
    $path = Join-Path $env:TEMP ('stock-installer-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-TestRoot {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) { [IO.Directory]::Delete($Path, $true) }
}

function Invoke-EmptyRootProbe {
    param([Parameter(Mandatory = $true)][string]$Root)
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command '$p=[Environment]::GetEnvironmentVariable(''STOCK_FIXTURE_ROOT''); $i=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue; if(-not $i -or -not $i.PSIsContainer -or (($i.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){exit 2}; if(@(Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop).Count -ne 0){exit 1}; exit 0'
    return $LASTEXITCODE
}

function Invoke-ReadOnlyCase {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Root,
        [string[]]$Extra = @()
    )
    $env:STOCK_SETUP_TEST_MODE = '1'
    try {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $core -Preflight -DryRun -TestRoot $Root @Extra | ForEach-Object { Write-Host $_ }
        $code = $LASTEXITCODE
    }
    finally { Remove-Item Env:STOCK_SETUP_TEST_MODE -ErrorAction SilentlyContinue }
    Write-Host ("{0}: exit={1}" -f $Name, $code)
    return $code
}

function Invoke-ReadOnlyCaseCapture {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Root,
        [string[]]$Extra = @()
    )
    $env:STOCK_SETUP_TEST_MODE = '1'
    try {
        $output = @(& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $core -Preflight -DryRun -TestRoot $Root @Extra 2>&1 | ForEach-Object { [string]$_ })
        $code = $LASTEXITCODE
    }
    finally { Remove-Item Env:STOCK_SETUP_TEST_MODE -ErrorAction SilentlyContinue }
    $output | ForEach-Object { Write-Host $_ }
    Write-Host ("{0}: exit={1}" -f $Name, $code)
    return [pscustomobject]@{ Code = $code; Output = ($output -join "`n") }
}

function Try-NewJunction {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Name
    )
    try {
        New-Item -ItemType Junction -Path $Path -Target $Target -Force -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-Host ("[SKIP] {0} reparse case unavailable: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Yellow
        return $false
    }
}

$roots = New-Object 'System.Collections.Generic.List[string]'
try {
    $emptyProbe = New-TestRoot
    $env:STOCK_FIXTURE_ROOT = $emptyProbe
    if ((Invoke-EmptyRootProbe -Root $emptyProbe) -ne 0) { throw 'empty fixed-root fixture was not accepted' }
    New-Item -ItemType File -Path (Join-Path $emptyProbe 'hidden.fixture') -Force | Out-Null
    if ((Invoke-EmptyRootProbe -Root $emptyProbe) -ne 1) { throw 'non-empty fixed-root fixture was not rejected' }
    Remove-Item Env:STOCK_FIXTURE_ROOT -ErrorAction SilentlyContinue
    Write-Host 'empty-root-bootstrap-probe: empty=0, hidden-content=1 PASS' -ForegroundColor Green

    $valid = New-TestRoot
    $roots.Add($valid)
    & git init $valid --quiet
    & git -C $valid remote add origin https://github.com/week833/stock.git
    'local change' | Set-Content -LiteralPath (Join-Path $valid 'local.txt') -Encoding ASCII
    if ((Invoke-ReadOnlyCase -Name 'dirty-valid-origin' -Root $valid) -ne 0) { throw 'dirty-valid-origin should pass' }

    $wrong = New-TestRoot
    $roots.Add($wrong)
    & git init $wrong --quiet
    & git -C $wrong remote add origin https://example.invalid/not-stock.git
    if ((Invoke-ReadOnlyCase -Name 'wrong-origin' -Root $wrong) -ne 2) { throw 'wrong-origin should fail closed' }

    $foreign = New-TestRoot
    $roots.Add($foreign)
    'foreign content' | Set-Content -LiteralPath (Join-Path $foreign 'foreign.txt') -Encoding ASCII
    if ((Invoke-ReadOnlyCase -Name 'nonempty-target' -Root $foreign) -ne 2) { throw 'nonempty-target should fail closed' }

    $missingGit = New-TestRoot
    $roots.Add($missingGit)
    & git init $missingGit --quiet
    & git -C $missingGit remote add origin https://github.com/week833/stock.git
    $fakeWingetBin = Join-Path $missingGit 'fake-winget'
    New-Item -ItemType Directory -Path $fakeWingetBin -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $fakeWingetBin 'winget.exe'), '')
    $oldPath = $env:Path
    try {
        $env:Path = $fakeWingetBin + ';' + $oldPath
        $missingGitPlan = Invoke-ReadOnlyCaseCapture -Name 'missing-git-existing-repo-with-winget' -Root $missingGit -Extra @('-SimulateMissingGit')
    }
    finally { $env:Path = $oldPath }
    if ($missingGitPlan.Code -ne 0 -or $missingGitPlan.Output -notmatch 'Git\.Git would be installed.*no install in preflight') {
        throw 'missing-git-existing-repo with winget should report a read-only Git.Git plan'
    }

    $fakeWinget = Join-Path $fakeWingetBin 'winget.cmd'
    $fakeWingetArgs = Join-Path $fakeWingetBin 'winget-args.log'
    @('@echo off', '>>"%~dp0winget-args.log" echo %*', 'exit /b 0') |
        Set-Content -LiteralPath $fakeWinget -Encoding ASCII
    $oldTestMode = $env:STOCK_SETUP_TEST_MODE
    $env:STOCK_SETUP_TEST_MODE = '1'
    try {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $core -ProbeWingetArgs -TestRoot $missingGit -TestWingetPath $fakeWinget | ForEach-Object { Write-Host $_ }
        $wingetProbeCode = $LASTEXITCODE
    }
    finally {
        if ($null -eq $oldTestMode) { Remove-Item Env:STOCK_SETUP_TEST_MODE -ErrorAction SilentlyContinue }
        else { $env:STOCK_SETUP_TEST_MODE = $oldTestMode }
    }
    if ($wingetProbeCode -ne 0) { throw "fake winget probe failed with exit $wingetProbeCode" }
    $wingetLines = @(Get-Content -LiteralPath $fakeWingetArgs -ErrorAction Stop)
    if ($wingetLines.Count -ne 2) { throw "fake winget should receive two package calls, got $($wingetLines.Count)" }
    foreach ($wingetLine in $wingetLines) {
        foreach ($requiredFlag in @('--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements')) {
            if ($wingetLine -notmatch [regex]::Escape($requiredFlag)) {
                throw "fake winget call omitted required non-interactive flag: $requiredFlag"
            }
        }
    }
    if (($wingetLines -join "`n") -notmatch 'Git\.Git' -or ($wingetLines -join "`n") -notmatch 'Python\.Python\.3\.12') {
        throw 'fake winget calls did not contain both fixed package ids'
    }
    Write-Host 'fake-winget-args: Git.Git/Python.Python.3.12 with agreements + --silent + --disable-interactivity: PASS' -ForegroundColor Green

    $oldTestMode = $env:STOCK_SETUP_TEST_MODE
    $env:STOCK_SETUP_TEST_MODE = '1'
    try {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $core -ProbeWingetArgs -TestRoot $missingGit -TestWingetPath (Join-Path $env:SystemRoot 'System32\cmd.exe') *> $null
        $unsafeWingetProbeCode = $LASTEXITCODE
    }
    finally {
        if ($null -eq $oldTestMode) { Remove-Item Env:STOCK_SETUP_TEST_MODE -ErrorAction SilentlyContinue }
        else { $env:STOCK_SETUP_TEST_MODE = $oldTestMode }
    }
    if ($unsafeWingetProbeCode -ne 2) { throw "unsafe fake winget path should fail closed with exit 2, got $unsafeWingetProbeCode" }
    Write-Host 'fake-winget-path-scope: outside TEMP fixture rejected with exit 2: PASS' -ForegroundColor Green

    $missingGitNoWinget = Invoke-ReadOnlyCase -Name 'missing-git-existing-repo-without-winget' -Root $missingGit -Extra @('-SimulateMissingGit', '-SimulateMissingWinget')
    if ($missingGitNoWinget -ne 2) { throw 'missing-git-existing-repo without winget should fail closed' }

    $reparseTarget = New-TestRoot
    $reparseRoot = Join-Path $env:TEMP ('stock-installer-reparse-root-' + [guid]::NewGuid().ToString('N'))
    $reparseLinkReady = $false
    try {
        $reparseLinkReady = Try-NewJunction -Path $reparseRoot -Target $reparseTarget -Name 'root'
        if ($reparseLinkReady) {
            $reparseRootCode = Invoke-ReadOnlyCase -Name 'reparse-root' -Root $reparseRoot
            if ($reparseRootCode -ne 2) { throw 'reparse install root should fail closed' }
            if (-not (Test-Path -LiteralPath $reparseTarget -PathType Container)) { throw 'reparse target was unexpectedly changed' }
        }
    }
    finally {
        if ($reparseLinkReady -and (Test-Path -LiteralPath $reparseRoot)) { Remove-Item -LiteralPath $reparseRoot -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $reparseTarget) { Remove-TestRoot -Path $reparseTarget }
    }

    $reparseChildCases = @(
        [pscustomobject]@{ Name = 'git'; Child = '.git' },
        [pscustomobject]@{ Name = 'venv'; Child = '.venv' }
    )
    foreach ($case in $reparseChildCases) {
        $childRoot = New-TestRoot
        $childTarget = New-TestRoot
        $childLink = Join-Path $childRoot $case.Child
        $childLinkReady = $false
        try {
            $childLinkReady = Try-NewJunction -Path $childLink -Target $childTarget -Name $case.Name
            if ($childLinkReady) {
                $childCode = Invoke-ReadOnlyCase -Name ("reparse-{0}" -f $case.Name) -Root $childRoot
                if ($childCode -ne 2) { throw ("reparse {0} path should fail closed" -f $case.Name) }
                if (-not (Test-Path -LiteralPath $childTarget -PathType Container)) { throw ("reparse {0} target was unexpectedly changed" -f $case.Name) }
            }
        }
        finally {
            if ($childLinkReady -and (Test-Path -LiteralPath $childLink)) { Remove-Item -LiteralPath $childLink -Force -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $childRoot) { Remove-TestRoot -Path $childRoot }
            if (Test-Path -LiteralPath $childTarget) { Remove-TestRoot -Path $childTarget }
        }
    }

    $missing = New-TestRoot
    $roots.Add($missing)
    if ((Invoke-ReadOnlyCase -Name 'missing-winget' -Root $missing -Extra @('-SimulateMissingGit', '-SimulateMissingPython', '-SimulateMissingWinget')) -ne 2) {
        throw 'missing-winget should fail closed when prerequisites are missing'
    }

    Write-Host '[OK] installer preflight cases passed.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ("[ERROR] {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    foreach ($root in $roots) { Remove-TestRoot -Path $root }
}
