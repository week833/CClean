[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$Root,
    [switch]$All,
    [switch]$Check,
    [switch]$Verify,
    [switch]$Legacy
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:MarginFloor = 256MB
$script:MarginRatio = 0.30
$script:Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
$script:ReposRoot = Join-Path $script:Root 'repos'
$script:SourcesDir = Join-Path $script:Root 'scripts\sources'
$script:ManifestPath = Join-Path $script:SourcesDir 'source_manifest_v1.json'
$script:ScriptPath = if ([string]::IsNullOrWhiteSpace($PSCommandPath)) { $null } else { [IO.Path]::GetFullPath($PSCommandPath) }
$script:LedgerPath = Join-Path $script:ReposRoot '.source_provenance.json'
$script:GitExe = $null
$script:Manifest = $null
$script:ManifestSha256 = $null
$script:Ledger = $null
$script:LedgerDirty = $false
$script:Failures = 0
$script:Skips = 0
$script:Successes = 0
$script:Missing = 0

function Fail([string]$Message) {
    Write-Host "[FAIL] $Message"
    $script:Failures++
}

function Stop-Fatal([string]$Message, [int]$Code = 2) {
    Write-Host "[ERROR] $Message"
    exit $Code
}

function Normalize-Url([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim().TrimEnd('/')
    $path = $null
    if ($v -match '^git@github\.com:(?<p>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$') {
        $path = $Matches.p
    } elseif ($v -match '^ssh://git@github\.com/(?<p>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$') {
        $path = $Matches.p
    } elseif ($v -match '^https?://(?:www\.)?github\.com/(?<p>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$') {
        $path = $Matches.p
    } else {
        return $null
    }
    if ($path.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
        $path = $path.Substring(0, $path.Length - 4)
    }
    if ($path -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { return $null }
    return ('github://' + $path).ToLowerInvariant()
}

function Test-RelativeTarget([string]$Target) {
    if ([string]::IsNullOrWhiteSpace($Target)) { return $false }
    if ($Target -match '^[\\/]' -or $Target -match '^[A-Za-z]:') { return $false }
    if ($Target -match '[/:*?"<>|]') { return $false }
    if ($Target -match '(^|\\)\.\.?(\\|$)') { return $false }
    if ($Target -match '/') { return $false }
    $parts = $Target -split '\\'
    if ($parts.Count -ne 2) { return $false }
    foreach ($part in $parts) {
        if ($part -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { return $false }
        if ($part.EndsWith('.') -or $part.EndsWith(' ')) { return $false }
        if ($part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { return $false }
    }
    return $true
}

function Test-InScope([string]$Path, [string]$Scope) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [IO.Path]::GetFullPath($Scope).TrimEnd('\')
    return ($full -ieq $root -or $full.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase))
}

function Test-NoReparseInAncestors([string]$Path, [string]$Scope) {
    if (-not (Test-InScope $Path $Scope)) { return $false }
    $cursor = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [IO.Path]::GetFullPath($Scope).TrimEnd('\')
    while ($true) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { return $false }
        if ($cursor -ieq $root) { break }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent -or $parent.FullName.TrimEnd('\') -ieq $cursor) { return $false }
        $cursor = $parent.FullName.TrimEnd('\')
    }
    return $true
}

function Test-RegularInScope([string]$Path, [string]$Scope, [bool]$Directory) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    try {
        $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        $root = [IO.Path]::GetFullPath($Scope).TrimEnd('\')
    } catch { return $false }
    if (-not (Test-InScope $full $root)) { return $false }
    $cursor = $full
    while ($true) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -eq $item -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { return $false }
        if ($cursor -ieq $root) { break }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent -or $parent.FullName.TrimEnd('\') -ieq $cursor) { return $false }
        $cursor = $parent.FullName.TrimEnd('\')
    }
    $leaf = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
    if ($null -eq $leaf -or (($leaf.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { return $false }
    return ([bool]$leaf.PSIsContainer -eq $Directory)
}

function Assert-RootBoundary {
    $testMode = ([string]$env:STOCK_SOURCE_TEST_MODE -eq '1')
    $expected = [IO.Path]::GetFullPath('D:\stock\GitHub').TrimEnd('\')
    if (-not $testMode) {
        if ($script:Root -ine $expected) { Stop-Fatal "Production source manager requires exact root D:\stock\GitHub (received $script:Root)." 2 }
        return
    }
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if (-not (Test-InScope $script:Root $tempRoot) -or -not (Test-Path -LiteralPath $script:Root -PathType Container) -or -not (Test-NoReparseInAncestors $script:Root $tempRoot)) {
        Stop-Fatal 'STOCK_SOURCE_TEST_MODE=1 only permits an existing real/non-reparse fixture below the system temporary directory.' 2
    }
}

function Assert-SourceManagerLayout {
    $required = @(
        [pscustomobject]@{ Label = 'source manager script'; Path = $script:ScriptPath; Directory = $false },
        [pscustomobject]@{ Label = 'source manifest'; Path = $script:ManifestPath; Directory = $false },
        [pscustomobject]@{ Label = 'scripts\\sources directory'; Path = $script:SourcesDir; Directory = $true }
    )
    foreach ($entry in $required) {
        if (-not (Test-RegularInScope ([string]$entry.Path) $script:Root ([bool]$entry.Directory))) {
            Stop-Fatal "$($entry.Label) must be a regular non-reparse path inside the install root: $($entry.Path)" 2
        }
    }
}

function Test-RealGitDirectory([string]$Target) {
    $gitPath = Join-Path $Target '.git'
    $git = Get-Item -LiteralPath $gitPath -Force -ErrorAction SilentlyContinue
    if ($null -eq $git -or -not $git.PSIsContainer) { return $false }
    if (($git.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    return (Test-NoReparseInAncestors $gitPath $script:ReposRoot)
}

function Find-Git {
    $candidate = $null
    if ([string]$env:STOCK_SOURCE_TEST_MODE -eq '1' -and -not [string]::IsNullOrWhiteSpace($env:STOCK_SOURCE_TEST_GIT)) {
        $candidate = $env:STOCK_SOURCE_TEST_GIT
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $command = Get-Command git.exe -ErrorAction SilentlyContinue
        if ($null -ne $command) { $candidate = $command.Source }
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        foreach ($p in @(
            (Join-Path ${env:ProgramFiles} 'Git\cmd\git.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe')
        )) {
            if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p -PathType Leaf)) { $candidate = $p; break }
        }
    }
    if ([string]::IsNullOrWhiteSpace($candidate) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        Stop-Fatal 'Git was not found. Install Git for Windows first.' 1
    }
    $script:GitExe = [IO.Path]::GetFullPath($candidate)
}

function Invoke-Git([string[]]$Arguments) {
    $output = @(& $script:GitExe @Arguments 2>&1)
    $code = $LASTEXITCODE
    $text = (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
    return [pscustomobject]@{ Code = [int]$code; Text = $text; Lines = @($output) }
}

function Get-FirstLine([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    return (($Text -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1).Trim()
}

function Get-ManifestHash([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($Path))) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $script:ManifestPath -PathType Leaf)) { Stop-Fatal "Manifest not found: $script:ManifestPath" }
    try { $raw = Get-Content -LiteralPath $script:ManifestPath -Raw -Encoding UTF8; $obj = $raw | ConvertFrom-Json }
    catch { Stop-Fatal "Manifest JSON is invalid: $($_.Exception.Message)" }
    if ($null -eq $obj -or [int]$obj.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace([string]$obj.generation)) {
        Stop-Fatal 'Manifest schema_version/generation is invalid.'
    }
    $sources = @($obj.sources)
    if ($sources.Count -ne 39) { Stop-Fatal "Manifest must contain 39 sources (37 primary + 2 legacy); found $($sources.Count)." }
    $ids = @{}
    $targets = @{}
    $urlTargets = @{}
    $validCategories = @('taiwan_market_data','global_market_data','machine_learning_forecasting','backtesting_engines','quant_portfolio_risk','legacy_compat')
    foreach ($s in $sources) {
        foreach ($field in @('id','scope','default_install','category','target','url','expected_branch','estimated_bytes','usage','license_note')) {
            if ($null -eq $s.PSObject.Properties[$field]) { Stop-Fatal "Manifest source is missing field '$field'." }
        }
        if ($s.default_install -isnot [bool]) { Stop-Fatal "Manifest source '$($s.id)' default_install must be boolean." }
        if ([string]::IsNullOrWhiteSpace([string]$s.id) -or $ids.ContainsKey([string]$s.id)) { Stop-Fatal "Manifest contains duplicate/empty id '$($s.id)'." }
        $ids[[string]$s.id] = $true
        if ([string]$s.scope -notin @('primary','legacy')) { Stop-Fatal "Manifest source '$($s.id)' has invalid scope." }
        if ($s.category -notin $validCategories) { Stop-Fatal "Manifest source '$($s.id)' has invalid category." }
        if (-not (Test-RelativeTarget ([string]$s.target))) { Stop-Fatal "Manifest source '$($s.id)' has unsafe target '$($s.target)'." }
        $targetKey = ([string]$s.target).ToLowerInvariant()
        if ($targets.ContainsKey($targetKey)) { Stop-Fatal "Manifest contains duplicate target '$($s.target)'." }
        $targets[$targetKey] = $true
        $normalized = Normalize-Url ([string]$s.url)
        if ($null -eq $normalized) { Stop-Fatal "Manifest source '$($s.id)' has unsupported URL '$($s.url)'." }
        $key = $normalized + '|' + $targetKey
        if ($urlTargets.ContainsKey($key)) { Stop-Fatal "Manifest contains duplicate normalized URL+target for '$($s.id)'." }
        $urlTargets[$key] = $true
        if ([string]$s.expected_branch -notmatch '^[A-Za-z0-9._/-]+$') { Stop-Fatal "Manifest source '$($s.id)' has invalid branch." }
        $bytes = 0L
        if (-not [Int64]::TryParse([string]$s.estimated_bytes, [Globalization.NumberStyles]::Integer, [Globalization.CultureInfo]::InvariantCulture, [ref]$bytes) -or $bytes -le 0) { Stop-Fatal "Manifest source '$($s.id)' has invalid estimated_bytes." }
        if ([string]::IsNullOrWhiteSpace([string]$s.usage) -or [string]::IsNullOrWhiteSpace([string]$s.license_note)) { Stop-Fatal "Manifest source '$($s.id)' needs usage and license_note." }
    }
    $primary = @($sources | Where-Object { $_.scope -eq 'primary' })
    $legacy = @($sources | Where-Object { $_.scope -eq 'legacy' })
    if ($primary.Count -ne 37 -or $legacy.Count -ne 2) { Stop-Fatal "Manifest scope counts invalid (primary=$($primary.Count), legacy=$($legacy.Count))." }
    $defaults = @($sources | Where-Object { $_.default_install -eq $true })
    if ($defaults.Count -ne 3 -or @($defaults | Where-Object { $_.scope -ne 'primary' }).Count -ne 0) { Stop-Fatal "Manifest must mark exactly 3 primary default_install sources; found $($defaults.Count)." }
    $aliases = @($obj.legacy_aliases)
    if ($aliases.Count -ne 1 -or [string]$aliases[0].source_id -ne 'twstock' -or -not $ids.ContainsKey('twstock')) { Stop-Fatal 'Manifest legacy twstock alias is invalid.' }
    $script:Manifest = [pscustomobject]@{ schema_version = 1; generation = [string]$obj.generation; sources = $sources; aliases = $aliases }
    $script:ManifestSha256 = Get-ManifestHash $script:ManifestPath
}

function Get-SelectedSources {
    if ($Legacy -and $All) { Stop-Fatal '--all cannot be combined with legacy mode.' 2 }
    if ($Legacy) { return @($script:Manifest.sources | Where-Object { $_.scope -eq 'legacy' }) }
    if ($All) { return @($script:Manifest.sources | Where-Object { $_.scope -eq 'primary' }) }
    return @($script:Manifest.sources | Where-Object { $_.scope -eq 'primary' -and $_.default_install -eq $true })
}

function Get-Target([object]$Source) { return Join-Path $script:ReposRoot ([string]$Source.target) }

function Get-RepoState([object]$Source, [string]$TargetOverride = $null) {
    $target = if ([string]::IsNullOrWhiteSpace($TargetOverride)) { Get-Target $Source } else { [IO.Path]::GetFullPath($TargetOverride) }
    $state = [ordered]@{ Source = $Source; Target = $target; Status = 'missing'; Head = $null; Dirty = $false; Reason = $null }
    if (-not (Test-InScope $target $script:ReposRoot) -or -not (Test-NoReparseInAncestors $target $script:ReposRoot)) { $state.Status = 'invalid'; $state.Reason = 'target is outside scope or has a reparse-point ancestor'; return [pscustomobject]$state }
    $item = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return [pscustomobject]$state }
    if (-not $item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { $state.Status = 'invalid'; $state.Reason = 'target is not a real directory'; return [pscustomobject]$state }
    if (-not (Test-RealGitDirectory $target)) { $state.Status = 'invalid'; $state.Reason = '.git is not a real in-scope directory'; return [pscustomobject]$state }
    $originResult = Invoke-Git @('-C',$target,'remote','get-url','origin')
    $branchResult = Invoke-Git @('-C',$target,'rev-parse','--abbrev-ref','HEAD')
    $headResult = Invoke-Git @('-C',$target,'rev-parse','HEAD')
    if ($originResult.Code -ne 0 -or $branchResult.Code -ne 0 -or $headResult.Code -ne 0) { $state.Status = 'invalid'; $state.Reason = 'Git metadata is unreadable'; return [pscustomobject]$state }
    $origin = Get-FirstLine $originResult.Text
    $branch = Get-FirstLine $branchResult.Text
    $head = Get-FirstLine $headResult.Text
    $expectedOrigin = Normalize-Url ([string]$Source.url)
    $actualOrigin = Normalize-Url $origin
    if ($null -eq $actualOrigin -or $actualOrigin -cne $expectedOrigin) { $state.Status = 'invalid'; $state.Reason = "origin mismatch (expected $expectedOrigin, actual $origin)"; return [pscustomobject]$state }
    if ([string]$branch -cne [string]$Source.expected_branch) { $state.Status = 'invalid'; $state.Reason = "branch mismatch (expected $($Source.expected_branch), actual $branch)"; return [pscustomobject]$state }
    if ([string]$head -notmatch '^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$') { $state.Status = 'invalid'; $state.Reason = 'HEAD is not a full hexadecimal commit id'; return [pscustomobject]$state }
    $statusResult = Invoke-Git @('-C',$target,'status','--porcelain=v1','--untracked-files=all')
    if ($statusResult.Code -ne 0) { $state.Status = 'invalid'; $state.Reason = 'Git status failed'; return [pscustomobject]$state }
    $state.Status = 'valid'; $state.Head = $head.ToLowerInvariant(); $state.Dirty = -not [string]::IsNullOrWhiteSpace($statusResult.Text)
    return [pscustomobject]$state
}

function Get-FreeBytes([string]$Path) {
    if ([string]$env:STOCK_SOURCE_TEST_MODE -eq '1' -and -not [string]::IsNullOrWhiteSpace($env:STOCK_SOURCE_TEST_FREE_BYTES)) {
        $v = 0L
        if ([Int64]::TryParse($env:STOCK_SOURCE_TEST_FREE_BYTES, [ref]$v)) { return $v }
    }
    $driveName = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    $drive = New-Object IO.DriveInfo($driveName)
    return [Int64]$drive.AvailableFreeSpace
}

function Test-DiskPreflight([object[]]$States) {
    $missing = @($States | Where-Object { $_.Status -eq 'missing' })
    $sum = 0L
    foreach ($state in $missing) { $sum += [Int64]$state.Source.estimated_bytes }
    $margin = [Math]::Max([Int64]$script:MarginFloor, [Int64][Math]::Ceiling($sum * $script:MarginRatio))
    $required = $sum + $margin
    $free = Get-FreeBytes $script:ReposRoot
    Write-Host ("[DISK] scope={0} missing_count={1} estimated_missing_bytes={2} safety_margin_bytes={3} required_bytes={4} free_bytes={5}" -f ($(if($All){'all'}else{'core'}),$missing.Count,$sum,$margin,$required,$free))
    if ($free -lt $required) { Fail "Insufficient free space for missing sources (need $required bytes, have $free)."; return $false }
    return $true
}

function Read-Ledger {
    Assert-LedgerPathSafe
    if (-not (Test-Path -LiteralPath $script:LedgerPath -PathType Leaf)) { $script:Ledger = [pscustomobject]@{ schema_version = 1; generation = $script:Manifest.generation; manifest_sha256 = $script:ManifestSha256; entries = @() }; return }
    try { $obj = Get-Content -LiteralPath $script:LedgerPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { Stop-Fatal "Ledger is invalid and was not changed: $script:LedgerPath" }
    if ([int]$obj.schema_version -ne 1 -or [string]$obj.manifest_sha256 -ne $script:ManifestSha256) { Stop-Fatal 'Ledger schema or manifest binding does not match; repair manually before update.' }
    $script:Ledger = [pscustomobject]@{ schema_version = 1; generation = $script:Manifest.generation; manifest_sha256 = $script:ManifestSha256; entries = @($obj.entries) }
}

function Assert-LedgerPathSafe {
    if (-not (Test-InScope $script:LedgerPath $script:ReposRoot) -or -not (Test-NoReparseInAncestors $script:LedgerPath $script:Root)) {
        Stop-Fatal 'Provenance ledger path is outside the canonical root or has a reparse-point ancestor.' 2
    }
    $item = Get-Item -LiteralPath $script:LedgerPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $item.PSIsContainer)) {
        Stop-Fatal 'Provenance ledger must be a regular non-reparse file; no changes were made.' 2
    }
}

function Set-LedgerEntry([object]$State) {
    if ($Check -or $Verify) { return }
    $entries = @($script:Ledger.entries | Where-Object { [string]$_.id -ne [string]$State.Source.id })
    $entries += [pscustomobject][ordered]@{
        id = [string]$State.Source.id
        relative_target = [string]$State.Source.target
        url = [string]$State.Source.url
        branch = [string]$State.Source.expected_branch
        head = [string]$State.Head
        observed_at = [DateTime]::UtcNow.ToString('o')
    }
    $script:Ledger = [pscustomobject]@{ schema_version = 1; generation = $script:Manifest.generation; manifest_sha256 = $script:ManifestSha256; entries = $entries }
    $script:LedgerDirty = $true
}

function Write-Ledger {
    if (-not $script:LedgerDirty -or $Check -or $Verify) { return }
    Assert-LedgerPathSafe
    if (-not (Test-Path -LiteralPath $script:ReposRoot -PathType Container)) { New-Item -ItemType Directory -Path $script:ReposRoot -Force | Out-Null }
    $temp = $script:LedgerPath + '.__tmp_' + [guid]::NewGuid().ToString('N')
    if (Test-Path -LiteralPath $temp) { Stop-Fatal "Ledger temporary path already exists: $temp" 2 }
    $json = $script:Ledger | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($false)))
    try {
        if (Test-Path -LiteralPath $script:LedgerPath -PathType Leaf) {
            $backup = $script:LedgerPath + '.__bak_' + [guid]::NewGuid().ToString('N')
            [IO.File]::Replace($temp, $script:LedgerPath, $backup, $true)
            if (Test-Path -LiteralPath $backup -PathType Leaf) { Remove-Item -LiteralPath $backup -Force }
        } else { [IO.File]::Move($temp, $script:LedgerPath) }
    } catch {
        Write-Host "[FAIL] Atomic ledger replace failed; temporary ledger retained: $temp"
        $script:Failures++
    }
}

function Invoke-NewClone([object]$State) {
    $source = $State.Source; $target = $State.Target
    $parent = Split-Path -Parent $target
    if (-not (Test-NoReparseInAncestors $parent $script:ReposRoot)) { Fail "Parent path is outside scope or contains a reparse point: $parent"; return $false }
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = $target + '.__codex_tmp_' + [guid]::NewGuid().ToString('N')
    if (Test-Path -LiteralPath $temp) { Fail "Temporary sibling already exists; not modified: $temp"; return $false }
    Write-Host "[CLONE] $($source.id) via temporary sibling"
    $clone = Invoke-Git @('-c','core.longpaths=true','clone','--branch',[string]$source.expected_branch,'--single-branch','--depth','1',[string]$source.url,$temp)
    if ($clone.Code -ne 0) { Fail "Clone failed; temporary path retained for review: $temp"; return $false }
    if (-not (Test-InScope $temp $script:ReposRoot) -or -not (Test-NoReparseInAncestors $temp $script:ReposRoot) -or -not (Test-Path -LiteralPath $temp -PathType Container) -or -not (Test-RealGitDirectory $temp)) { Fail "Temporary clone failed scope/.git/reparse validation; retained: $temp"; return $false }
    $tempState = Get-RepoState $source $temp
    if ($tempState.Status -ne 'valid') { Fail "Temporary clone verification failed ($($tempState.Reason)); retained: $temp"; return $false }
    if (Test-Path -LiteralPath $target) { Fail "Target appeared during clone; temporary path retained: $temp"; return $false }
    try { [IO.Directory]::Move($temp, $target) }
    catch { Fail "Atomic rename failed; temporary path retained: $temp"; return $false }
    $finalState = Get-RepoState $source
    if ($finalState.Status -ne 'valid') { Fail "Post-rename verification failed ($($finalState.Reason)); target was not overwritten: $target"; return $false }
    $State.Head = $finalState.Head
    Set-LedgerEntry $finalState
    Write-Host "[OK] New source installed: $target"
    return $true
}

function Invoke-Source([object]$State) {
    $source = $State.Source
    if ($State.Status -eq 'missing') {
        $script:Missing++
        if ($Check -or $Verify) { Write-Host "[CHECK] $($source.id): not downloaded"; if ($Verify) { Fail "Required source is missing: $($source.id)" }; return }
        if (Invoke-NewClone $State) { $script:Successes++ }
        return
    }
    if ($State.Status -eq 'invalid') { Fail "$($source.id): $($State.Reason)"; return }
    if ($State.Dirty) {
        Write-Host "[SKIP] Dirty repository: $($source.id); not modified: $($State.Target)"
        $script:Skips++
        Set-LedgerEntry $State
        return
    }
    if ($Check -or $Verify) { Write-Host "[OK] $($source.id): clean repository, origin and branch match"; Set-LedgerEntry $State; return }
    $pull = Invoke-Git @('-C',$State.Target,'pull','--ff-only','origin',[string]$source.expected_branch)
    if ($pull.Code -ne 0) { Fail "Fast-forward-only update failed: $($State.Target)"; return }
    $after = Get-RepoState $source
    if ($after.Status -ne 'valid') { Fail "Post-pull verification failed ($($after.Reason)): $($State.Target)"; return }
    Set-LedgerEntry $after
    $script:Successes++
    Write-Host "[OK] Updated clean source: $($source.id)"
}

function Invoke-Alias([object]$AliasSource) {
    $state = Get-RepoState $AliasSource
    if ($state.Status -eq 'missing') {
        Write-Host '[ALIAS] twstock shared alias is not present; no second clone or pull was attempted.'
        if (-not $Check -and -not $Verify) { Fail 'Legacy mode requires the primary twstock clone for alias verification.' }
        elseif ($Verify) { Fail 'Required shared twstock alias is missing.' }
        return
    }
    if ($state.Status -eq 'invalid') { Fail "Shared twstock alias verification failed: $($state.Reason)"; return }
    if ($state.Dirty) { Write-Host '[ALIAS] twstock shared alias is dirty; verification passed, no pull attempted.' }
    else { Write-Host '[ALIAS] twstock shared alias origin/branch verified; no second pull attempted.' }
}

Assert-RootBoundary
Assert-SourceManagerLayout
Read-Manifest
Find-Git
if ($Check -and $Verify) { Stop-Fatal '--check and --verify are mutually exclusive.' 2 }
if ($Legacy -and $All) { Stop-Fatal '--all is not valid in legacy mode.' 2 }
if (-not (Test-NoReparseInAncestors $script:ReposRoot $script:Root)) { Stop-Fatal 'Canonical repos path is outside root or has a reparse-point ancestor.' }
$selected = @(Get-SelectedSources)
if ($selected.Count -eq 0) { Stop-Fatal 'No sources selected.' }
$scopeName = if ($Legacy) { 'legacy' } elseif ($All) { 'all' } else { 'core' }
$modeName = if ($Check) { 'check' } elseif ($Verify) { 'verify' } else { 'update' }
Write-Host "[INFO] source scope=$scopeName mode=$modeName count=$($selected.Count) root=$script:ReposRoot"
Read-Ledger

$states = @()
foreach ($source in $selected) {
    $state = Get-RepoState $source
    $states += $state
    if ($state.Status -eq 'invalid') { Fail "$($source.id): $($state.Reason)" }
}
if ($script:Failures -gt 0) { Write-Ledger; exit 1 }
if (-not $Check -and -not $Verify -and -not (Test-DiskPreflight $states)) { Write-Ledger; exit 1 }
foreach ($state in $states) { Invoke-Source $state }
if ($Legacy) { Invoke-Alias ($script:Manifest.sources | Where-Object { $_.id -eq 'twstock' } | Select-Object -First 1) }
Write-Ledger
Write-Host ("[SUMMARY] scope={0} mode={1} success={2} skipped={3} missing={4} failed={5}" -f $scopeName,$modeName,$script:Successes,$script:Skips,$script:Missing,$script:Failures)
if ($script:Failures -gt 0) { exit 1 }
exit 0
