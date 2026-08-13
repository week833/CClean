[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$sourceScript = Join-Path $projectRoot 'scripts\compat\repair_legacy_paths.cmd'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('stock-repair-safety-' + [Guid]::NewGuid().ToString('N'))
$repo = Join-Path $fixture 'repo'
$legacy = Join-Path $fixture 'legacy-parent\stock'

function New-JunctionSafe([string]$Link, [string]$Target) {
    $parent = Split-Path -Parent $Link
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
}

function Remove-JunctionSafe([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        throw "Refusing to remove non-reparse fixture path: $Path"
    }
    $p = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/c', 'rmdir', $Path) -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -ne 0 -or (Test-Path -LiteralPath $Path)) {
        throw "Could not remove fixture junction: $Path"
    }
}

function Invoke-Repair([string[]]$Arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $quoted = @('call', ('"' + (Join-Path $repo 'scripts\compat\repair_legacy_paths.cmd') + '"')) + $Arguments
    $psi.Arguments = '/d /c ' + ($quoted -join ' ')
    $psi.WorkingDirectory = $repo
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables['STOCK_REPAIR_TEST_MODE'] = '1'
    $psi.EnvironmentVariables['STOCK_REPAIR_ROOT'] = $repo
    $psi.EnvironmentVariables['STOCK_REPAIR_LEGACY_ROOT'] = $legacy
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function Get-FixtureSnapshot([string]$Root) {
    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($item in @(Get-ChildItem -LiteralPath $Root -Force -Recurse -ErrorAction Stop | Sort-Object FullName)) {
        $relative = $item.FullName.Substring($Root.Length).TrimStart('\')
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $targets = @($item.Target)
            [void]$rows.Add("R|$relative|$($targets -join ',')")
        } elseif ($item.PSIsContainer) {
            [void]$rows.Add("D|$relative|$($item.Attributes)")
        } else {
            $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            [void]$rows.Add("F|$relative|$($item.Length)|$hash")
        }
    }
    return ($rows -join "`n")
}

function Assert-Exit([object]$Result, [int]$Expected, [string]$Message) {
    if ($Result.ExitCode -ne $Expected) {
        throw "$Message (exit=$($Result.ExitCode))`n$($Result.StdOut)`n$($Result.StdErr)"
    }
}

function Assert-JunctionTarget([string]$Link, [string]$Expected) {
    $item = Get-Item -LiteralPath $Link -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        throw "Expected junction was not created: $Link"
    }
    $targets = @($item.Target)
    if ($targets.Count -ne 1) { throw "Junction did not expose exactly one target: $Link" }
    $actual = [string]$targets[0]
    if (-not [IO.Path]::IsPathRooted($actual)) { $actual = Join-Path $item.DirectoryName $actual }
    $actual = [IO.Path]::GetFullPath($actual).TrimEnd('\')
    $want = [IO.Path]::GetFullPath($Expected).TrimEnd('\')
    if ($actual -ine $want) { throw "Unexpected junction target: $Link -> $actual; expected $want" }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $repo 'scripts\compat'),(Join-Path $repo 'repos\taiwan_market_data'),(Join-Path $repo 'github_sources'),(Split-Path -Parent $legacy) -Force | Out-Null
    Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $repo 'scripts\compat\repair_legacy_paths.cmd') -Force
    $target = Join-Path $repo 'repos\taiwan_market_data\twstock'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $target 'sentinel.txt') -Value 'fixture' -Force | Out-Null
    $twLink = Join-Path $repo 'repos\twstock'
    $githubLink = Join-Path $repo 'github_sources\twstock'
    $legacyLink = $legacy

    # CHECK is strictly read-only, including when links are missing.
    $before = Get-FixtureSnapshot $fixture
    $check = Invoke-Repair @('--check')
    Assert-Exit $check 0 'Read-only check failed for a safe missing-link fixture'
    $after = Get-FixtureSnapshot $fixture
    if ($before -cne $after) { throw 'CHECK changed the fixture snapshot' }
    if ($check.StdOut -notmatch '\[MISSING\]') { throw 'CHECK did not report missing links' }

    # A target ancestor junction to an external directory is rejected.
    $external = Join-Path $fixture 'external-target'
    New-Item -ItemType Directory -Path (Join-Path $external 'twstock') -Force | Out-Null
    $targetParent = Join-Path $repo 'repos\taiwan_market_data'
    [IO.Directory]::Delete($targetParent, $true)
    New-JunctionSafe $targetParent $external
    $targetBefore = Get-FixtureSnapshot $fixture
    $externalTarget = Invoke-Repair @('--check')
    if ($externalTarget.ExitCode -eq 0 -or $externalTarget.StdOut -notmatch 'target ancestor is a reparse point') {
        throw "External target ancestor was not rejected`n$($externalTarget.StdOut)`n$($externalTarget.StdErr)"
    }
    if ($targetBefore -cne (Get-FixtureSnapshot $fixture)) { throw 'External-target rejection changed the fixture' }
    Remove-JunctionSafe $targetParent
    New-Item -ItemType Directory -Path $targetParent,$target -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $target 'sentinel.txt') -Value 'fixture' -Force | Out-Null

    # A link parent junction to an external directory is rejected.
    $externalParent = Join-Path $fixture 'external-parent'
    New-Item -ItemType Directory -Path (Join-Path $externalParent 'twstock') -Force | Out-Null
    $githubParent = Join-Path $repo 'github_sources'
    [IO.Directory]::Delete($githubParent, $true)
    New-JunctionSafe $githubParent $externalParent
    $parentBefore = Get-FixtureSnapshot $fixture
    $externalLinkParent = Invoke-Repair @('--check')
    if ($externalLinkParent.ExitCode -eq 0 -or $externalLinkParent.StdOut -notmatch 'link parent is outside or has a reparse ancestor') {
        throw "External link parent was not rejected`n$($externalLinkParent.StdOut)`n$($externalLinkParent.StdErr)"
    }
    if ($parentBefore -cne (Get-FixtureSnapshot $fixture)) { throw 'External-parent rejection changed the fixture' }
    Remove-JunctionSafe $githubParent
    New-Item -ItemType Directory -Path $githubParent -Force | Out-Null

    # Existing junction with the wrong target is rejected and preserved.
    $wrong = Join-Path $repo 'repos\wrong-target'
    New-Item -ItemType Directory -Path $wrong -Force | Out-Null
    New-JunctionSafe $twLink $wrong
    $wrongBefore = Get-FixtureSnapshot $fixture
    $wrongTarget = Invoke-Repair @('--check')
    if ($wrongTarget.ExitCode -eq 0 -or $wrongTarget.StdOut -notmatch 'junction target mismatch') {
        throw "Wrong existing target was not rejected`n$($wrongTarget.StdOut)`n$($wrongTarget.StdErr)"
    }
    if ($wrongBefore -cne (Get-FixtureSnapshot $fixture)) { throw 'Wrong-target rejection changed the fixture' }
    Assert-JunctionTarget $twLink $wrong
    Remove-JunctionSafe $twLink

    # Existing ordinary directories are kept untouched.
    New-Item -ItemType Directory -Path $twLink -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $twLink 'keep.txt') -Value 'keep' -Force | Out-Null
    $keepBefore = Get-FixtureSnapshot $fixture
    $keep = Invoke-Repair @('--check')
    Assert-Exit $keep 0 'Real-path KEEP check failed'
    if ($keepBefore -cne (Get-FixtureSnapshot $fixture)) { throw 'Real-path KEEP changed the fixture' }
    [IO.Directory]::Delete($twLink, $true)

    # APPLY requires --confirm and only creates approved missing junctions.
    $noConfirm = Invoke-Repair @('--apply')
    Assert-Exit $noConfirm 2 'APPLY without --confirm was not rejected'
    $apply = Invoke-Repair @('--apply', '--confirm')
    Assert-Exit $apply 0 'Safe APPLY failed'
    Assert-JunctionTarget $legacyLink $repo
    Assert-JunctionTarget $twLink $target
    Assert-JunctionTarget $githubLink $target
    $links = @(Get-ChildItem -LiteralPath $fixture -Force -Recurse | Where-Object {
        (($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
    })
    if ($links.Count -ne 3) { throw "APPLY created an unexpected reparse count: $($links.Count)" }

    Write-Output '[OK] Test-RepairLegacyPathsSafety: CHECK zero-write, reparse ancestor rejection, wrong-target preservation, KEEP, and confirmed APPLY passed.'
    exit 0
} finally {
    foreach ($link in @($legacyLink, $twLink, $githubLink, (Join-Path $repo 'repos\wrong-target'), (Join-Path $repo 'repos\taiwan_market_data'))) {
        if (Test-Path -LiteralPath $link) {
            $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
            if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                Remove-JunctionSafe $link
            }
        }
    }
    if (Test-Path -LiteralPath $fixture) {
        [IO.Directory]::Delete($fixture, $true)
    }
}
