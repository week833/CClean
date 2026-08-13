$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$sourceDir = Split-Path -Parent $PSScriptRoot
$managerSource = Join-Path $sourceDir 'source_manager.ps1'
$manifestSource = Join-Path $sourceDir 'source_manifest_v1.json'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('stock_source_manager_fixture_' + [guid]::NewGuid().ToString('N'))
$fakeGit = Join-Path $fixture 'bin\git.exe'
$root = Join-Path $fixture 'fixture-root'
$managerFixture = Join-Path $root 'scripts\sources\source_manager.ps1'

function Snapshot([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    @(Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $kind = if ($_.PSIsContainer) { 'D' } else { 'F' }
        $length = if ($_.PSIsContainer) { 0 } else { $_.Length }
        "$($_.FullName)|$kind|$length|$($_.Attributes)"
    } | Sort-Object)
}

function Invoke-Manager([string[]]$ManagerArgs, [hashtable]$Env = @{}) {
    $old = @{}
    foreach ($name in @('STOCK_SOURCE_TEST_MODE','STOCK_SOURCE_TEST_GIT','STOCK_SOURCE_TEST_FREE_BYTES','FAKE_DIRTY','FAKE_BRANCH_MODE','FAKE_LOG')) {
        $old[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    try {
        $env:STOCK_SOURCE_TEST_MODE = '1'
        $env:STOCK_SOURCE_TEST_GIT = $fakeGit
        if ($Env.ContainsKey('STOCK_SOURCE_TEST_FREE_BYTES')) { $env:STOCK_SOURCE_TEST_FREE_BYTES = [string]$Env.STOCK_SOURCE_TEST_FREE_BYTES } else { $env:STOCK_SOURCE_TEST_FREE_BYTES = '999999999999' }
        foreach ($name in @('FAKE_DIRTY','FAKE_BRANCH_MODE','FAKE_LOG')) {
            if ($Env.ContainsKey($name)) { Set-Item -Path ("Env:{0}" -f $name) -Value ([string]$Env[$name]) } else { Remove-Item -Path ("Env:{0}" -f $name) -ErrorAction SilentlyContinue }
        }
        $output = (& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $managerFixture -Root $root @ManagerArgs 2>&1 | Out-String)
        [pscustomobject]@{ Code = [int]$LASTEXITCODE; Output = $output }
    } finally {
        foreach ($name in $old.Keys) {
            if ($null -eq $old[$name]) { Remove-Item -Path ("Env:{0}" -f $name) -ErrorAction SilentlyContinue }
            else { Set-Item -Path ("Env:{0}" -f $name) -Value $old[$name] }
        }
    }
}

function Write-AsciiCrLf([string]$Path, [string]$Text) {
    $Text = $Text.Replace("`r`n", "`n").Replace("`n", "`r`n")
    [IO.File]::WriteAllText($Path, $Text, [Text.Encoding]::ASCII)
}

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'scripts\sources'), (Split-Path $fakeGit) | Out-Null
    Copy-Item -LiteralPath $managerSource -Destination $managerFixture
    Copy-Item -LiteralPath $manifestSource -Destination (Join-Path $root 'scripts\sources\source_manifest_v1.json')
    $fake = @'
using System;
using System.IO;
using System.Linq;
class FakeGit {
  static string Arg(string[] a, string key) { int i=Array.IndexOf(a,key); return i>=0 && i+1<a.Length ? a[i+1] : ""; }
  static string Url(string[] a) { return a.FirstOrDefault(x => x.StartsWith("https://github.com/", StringComparison.OrdinalIgnoreCase)) ?? ""; }
  static string Target(string[] a) { return Arg(a,"-C"); }
  static string RepoUrl(string[] a) { string u=Url(a); if(String.IsNullOrEmpty(u)){ string p=Path.Combine(Target(a),".git","fake-origin"); if(File.Exists(p)) u=File.ReadAllText(p); } return u; }
  static string Branch(string u) {
    if (Environment.GetEnvironmentVariable("FAKE_BRANCH_MODE") == "wrong") return "wrong";
    if (u.Contains("mlouielu/twstock")) return "dev";
    if (u.Contains("sacahan/CasualMarket")) return "main";
    if (u.Contains("ZhuLinsen")) return "main";
    if (u.Contains("OpenBB-finance")) return "develop";
    if (u.Contains("vectorbt")) return "master";
    if (u.Contains("zipline-reloaded") || u.Contains("stefan-jansen/alphalens") || u.Contains("pyfolio-reloaded") || u.Contains("empyrical-reloaded") || u.Contains("PyPortfolioOpt") || u.Contains("python-stock-radar") || u.Contains("k66inthesky/TW-stock")) return "main";
    if (u.Contains("freqtrade")) return "develop";
    return "master";
  }
  static int Main(string[] a) {
    string joined=String.Join(" ",a).ToLowerInvariant(); string u=RepoUrl(a);
    if (joined.Contains(" clone ") || (a.Length>0 && a[0].Equals("clone",StringComparison.OrdinalIgnoreCase))) {
      string target=a[a.Length-1]; Directory.CreateDirectory(Path.Combine(target,".git")); File.WriteAllText(Path.Combine(target,".git","fake-origin"),Url(a)); File.WriteAllText(Path.Combine(target,"fixture.txt"),"fixture"); return 0;
    }
    if (joined.Contains("remote get-url origin")) { Console.WriteLine(u); return 0; }
    if (joined.Contains("--abbrev-ref")) { Console.WriteLine(Branch(u)); return 0; }
    if (joined.Contains("rev-parse head")) { Console.WriteLine("0123456789012345678901234567890123456789"); return 0; }
    if (joined.Contains("status")) { if (Environment.GetEnvironmentVariable("FAKE_DIRTY")=="1") Console.WriteLine(" M fixture.txt"); return 0; }
    if (joined.Contains("pull --ff-only")) { string log=Environment.GetEnvironmentVariable("FAKE_LOG"); if(!String.IsNullOrEmpty(log)) File.AppendAllText(log,"PULL\n"); return 0; }
    return 0;
  }
}
'@
    Add-Type -TypeDefinition $fake -OutputAssembly $fakeGit -OutputType ConsoleApplication

    $core = Invoke-Manager -ManagerArgs @()
    if ($core.Code -ne 0 -or $core.Output -notmatch 'scope=core mode=update count=3' -or $core.Output -notmatch 'success=3') { throw "core new-clone fixture failed`n$($core.Output)" }
    $ledger = Join-Path $root 'repos\.source_provenance.json'
    if (-not (Test-Path -LiteralPath $ledger)) { throw 'atomic provenance ledger was not created' }
    $ledgerOriginal = [IO.File]::ReadAllText($ledger)
    $ledgerObject = Get-Content -LiteralPath $ledger -Raw | ConvertFrom-Json
    if (@($ledgerObject.entries).Count -ne 3 -or $ledgerObject.entries[0].PSObject.Properties['head'] -eq $null) { throw 'ledger entries are incomplete' }

    $before = @(Snapshot $root)
    $check = Invoke-Manager -ManagerArgs @('-Check')
    if ($check.Code -ne 0 -or $check.Output -notmatch 'mode=check count=3') { throw "check fixture failed`n$($check.Output)" }
    if (@(Compare-Object $before @(Snapshot $root)).Count -ne 0) { throw 'check mode changed fixture files' }

    $dirty = Invoke-Manager -ManagerArgs @() -Env @{ FAKE_DIRTY = '1'; FAKE_LOG = (Join-Path $fixture 'dirty.log') }
    if ($dirty.Code -ne 0 -or $dirty.Output -notmatch '\[SKIP\] Dirty repository') { throw "dirty skip fixture failed`n$($dirty.Output)" }
    if (Test-Path -LiteralPath (Join-Path $fixture 'dirty.log')) { throw 'dirty repository attempted pull' }

    $wrongBranch = Invoke-Manager -ManagerArgs @('-Check') -Env @{ FAKE_BRANCH_MODE = 'wrong' }
    if ($wrongBranch.Code -eq 0 -or $wrongBranch.Output -notmatch 'branch mismatch') { throw 'branch mismatch was not fail-closed' }

    $lowDisk = Invoke-Manager -ManagerArgs @() -Env @{ STOCK_SOURCE_TEST_FREE_BYTES = '1' }
    if ($lowDisk.Code -eq 0 -or $lowDisk.Output -notmatch 'Insufficient free space') { throw 'low disk preflight was not enforced' }

    $manifest = Join-Path $root 'scripts\sources\source_manifest_v1.json'
    $duplicate = Get-Content -LiteralPath $manifest -Raw
    $duplicate = $duplicate.Replace('"target":"taiwan_market_data\\daily_stock_analysis"', '"target":"taiwan_market_data\\FinMind"')
    Write-AsciiCrLf $manifest $duplicate
    $dup = Invoke-Manager -ManagerArgs @('-Check')
    if ($dup.Code -eq 0 -or $dup.Output -notmatch 'duplicate target') { throw 'duplicate manifest target was accepted' }
    Copy-Item -LiteralPath $manifestSource -Destination $manifest -Force

    $outside = Join-Path $fixture 'outside'
    New-Item -ItemType Directory -Force -Path $outside | Out-Null
    $manifestOutside = Join-Path $outside 'manifest-outside.json'
    Write-AsciiCrLf $manifestOutside ([IO.File]::ReadAllText($manifestSource))
    $manifestSymlinked = $false
    try {
        Remove-Item -LiteralPath $manifest -Force
        New-Item -ItemType SymbolicLink -Path $manifest -Target $manifestOutside -ErrorAction Stop | Out-Null
        $manifestSymlinked = $true
    } catch {
        Write-Output 'SKIP: manifest symlink fixture unavailable (symbolic-link privilege denied)'
        if (-not (Test-Path -LiteralPath $manifest)) { Copy-Item -LiteralPath $manifestSource -Destination $manifest -Force }
    }
    if ($manifestSymlinked) {
        $manifestLinkCheck = Invoke-Manager -ManagerArgs @('-Check')
        if ($manifestLinkCheck.Code -eq 0 -or $manifestLinkCheck.Output -notmatch 'source manifest must be a regular non-reparse') {
            throw 'manifest symlink was accepted'
        }
        Remove-Item -LiteralPath $manifest -Force
        Copy-Item -LiteralPath $manifestSource -Destination $manifest -Force
    }

    $target = Join-Path $root 'repos\taiwan_market_data\FinMind'
    Remove-Item -LiteralPath $target -Recurse -Force
    New-Item -ItemType Junction -Path $target -Target $outside | Out-Null
    $reparse = Invoke-Manager -ManagerArgs @('-Check')
    if ($reparse.Code -eq 0 -or $reparse.Output -notmatch 'reparse|scope') { throw 'reparse target was not rejected' }

    Remove-Item -LiteralPath $ledger -Force
    Write-AsciiCrLf $ledger '{not-json'
    $malformed = Invoke-Manager -ManagerArgs @('-Check')
    if ($malformed.Code -eq 0 -or $malformed.Output -notmatch 'Ledger is invalid') { throw 'malformed ledger was accepted' }
    Write-AsciiCrLf $ledger $ledgerOriginal
    $manifestText = [IO.File]::ReadAllText($manifest)
    Write-AsciiCrLf $manifest ($manifestText.Replace('2026-08-13-source-v1','fixture-manifest-mismatch'))
    $mismatch = Invoke-Manager -ManagerArgs @('-Check')
    if ($mismatch.Code -eq 0 -or $mismatch.Output -notmatch 'manifest binding') { throw 'manifest/ledger mismatch was accepted' }
    Write-AsciiCrLf $manifest $manifestText

    $managerTokens = $null
    $managerParseErrors = $null
    $managerAst = [System.Management.Automation.Language.Parser]::ParseFile($managerSource, [ref]$managerTokens, [ref]$managerParseErrors)
    if (@($managerParseErrors).Count -ne 0) { throw 'source manager AST parse failed' }
    $gitAssignments = @($managerAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Extent.Text -match '\$candidate\s*=\s*\$env:STOCK_SOURCE_TEST_GIT'
    }, $true))
    if ($gitAssignments.Count -ne 1) { throw 'STOCK_SOURCE_TEST_GIT assignment shape changed' }
    $guard = $gitAssignments[0].Parent
    while ($null -ne $guard -and $guard -isnot [System.Management.Automation.Language.IfStatementAst]) { $guard = $guard.Parent }
    $guardText = if ($null -eq $guard) { '' } else { $guard.Extent.Text }
    if ($null -eq $guard -or $guardText -notmatch '\$env:STOCK_SOURCE_TEST_MODE\s*-eq\s*[''\"]1[''\"]' -or $guardText -notmatch '\$env:STOCK_SOURCE_TEST_GIT') {
        throw 'STOCK_SOURCE_TEST_GIT is not guarded by STOCK_SOURCE_TEST_MODE=1'
    }

    $oldTestMode = $env:STOCK_SOURCE_TEST_MODE; $oldInjectedGit = $env:STOCK_SOURCE_TEST_GIT; $oldFakeLog = $env:FAKE_LOG
    $productionFakeLog = Join-Path $fixture 'production-fake.log'
    $fixedManagerPath = [IO.Path]::GetFullPath((Join-Path 'D:\stock\GitHub' 'scripts\sources\source_manager.ps1'))
    $managerIsFixed = ([IO.Path]::GetFullPath($managerSource) -ieq $fixedManagerPath)
    try {
        Remove-Item Env:STOCK_SOURCE_TEST_MODE -ErrorAction SilentlyContinue
        $env:STOCK_SOURCE_TEST_GIT = $fakeGit
        $env:FAKE_LOG = $productionFakeLog
        $prod = (& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $managerSource -Root 'D:\stock\GitHub' -Check 2>&1 | Out-String)
        if ($managerIsFixed) {
            if ($LASTEXITCODE -ne 0 -or $prod -match '(?i)fixture|fake') { throw "production fake-git injection was not ignored`n$prod" }
        } else {
            if ($LASTEXITCODE -eq 0 -or $prod -notmatch '(?i)source manager script|inside the install root|regular non-reparse') {
                throw "non-fixed source manager did not fail the fixed-layout guard`n$prod"
            }
        }
        if ((Test-Path -LiteralPath $productionFakeLog) -and (Get-Item -LiteralPath $productionFakeLog).Length -gt 0) {
            throw 'production-like check touched fake git log'
        }
    } finally {
        if ($null -eq $oldTestMode) { Remove-Item Env:STOCK_SOURCE_TEST_MODE -ErrorAction SilentlyContinue } else { $env:STOCK_SOURCE_TEST_MODE = $oldTestMode }
        if ($null -eq $oldInjectedGit) { Remove-Item Env:STOCK_SOURCE_TEST_GIT -ErrorAction SilentlyContinue } else { $env:STOCK_SOURCE_TEST_GIT = $oldInjectedGit }
        if ($null -eq $oldFakeLog) { Remove-Item Env:FAKE_LOG -ErrorAction SilentlyContinue } else { $env:FAKE_LOG = $oldFakeLog }
    }

    $ledgerOutside = Join-Path $outside 'ledger-target.json'
    Write-AsciiCrLf $ledgerOutside $ledgerOriginal
    Remove-Item -LiteralPath $ledger -Force
    $ledgerSymlinked = $false
    try {
        New-Item -ItemType SymbolicLink -Path $ledger -Target $ledgerOutside -ErrorAction Stop | Out-Null
        $ledgerSymlinked = $true
    } catch {
        Write-Output 'SKIP: ledger symlink fixture unavailable (symbolic-link privilege denied)'
    }
    if ($ledgerSymlinked) {
        $ledgerLinkCheck = Invoke-Manager -ManagerArgs @('-Check')
        if ($ledgerLinkCheck.Code -eq 0 -or $ledgerLinkCheck.Output -notmatch 'reparse|regular') { throw 'ledger symlink was accepted' }
        Remove-Item -LiteralPath $ledger -Force
    }
    Write-AsciiCrLf $ledger $ledgerOriginal

    $external = (& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $managerSource -Root $outside -Check 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -or $external -notmatch 'exact root|temporary directory') { throw 'external root was accepted' }

    $repoRoot = Split-Path -Parent (Split-Path -Parent $sourceDir)
    $stockWrapper = Join-Path $repoRoot 'DOWNLOAD_STOCK_SOURCES.cmd'
    $legacyWrapper = Join-Path $repoRoot 'DOWNLOAD_LEGACY_SOURCES.cmd'
    foreach ($wrapper in @($stockWrapper, $legacyWrapper)) {
        $wrapperText = [IO.File]::ReadAllText($wrapper, [Text.Encoding]::ASCII)
        if ($wrapperText -match '%\*' -or $wrapperText -match 'MODE_ARGS') { throw "wrapper forwards raw arguments or uses dynamic mode: $wrapper" }
    }
    $extraStock = (& cmd.exe /d /c "`"$stockWrapper`" --check --all EXTRA" 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 2 -or $extraStock -notmatch 'Unsupported source option') { throw 'stock third argument was not rejected' }
    $extraLegacy = (& cmd.exe /d /c "`"$legacyWrapper`" --check EXTRA" 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 2 -or $extraLegacy -notmatch 'Unsupported legacy source option') { throw 'legacy extra argument was not rejected' }
    $meta = (& cmd.exe /d /c "`"$stockWrapper`" `"--check^&echo INJECT`"" 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 2 -or $meta -match 'INJECT') { throw 'metacharacter-like quoted option was not fail-closed' }
    $oldErrorLevel = [Environment]::GetEnvironmentVariable('ERRORLEVEL', 'Process')
    try {
        $env:ERRORLEVEL = '0'
        $envLevelOutput = (& cmd.exe /d /c "`"$stockWrapper`" --check" 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0 -or $envLevelOutput -notmatch 'scope=core mode=check') { throw 'inherited ERRORLEVEL environment variable affected wrapper dispatch' }
    } finally {
        if ($null -eq $oldErrorLevel) { Remove-Item Env:ERRORLEVEL -ErrorAction SilentlyContinue } else { $env:ERRORLEVEL = $oldErrorLevel }
    }
    Write-Output 'source manager fixture contracts: PASS'
    Write-Output 'covered: core=3, atomic ledger, check zero writes, dirty skip, branch mismatch, low disk, duplicate manifest, reparse guard, external root rejection, wrapper allowlist/extra/metachar/errorlevel guards'
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
