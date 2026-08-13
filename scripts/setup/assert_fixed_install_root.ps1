[CmdletBinding()]
param(
    [Parameter(DontShow = $true)]
    [string]$TestRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$FixedRoot = 'D:\stock\GitHub'
$ExpectedOrigin = 'https://github.com/week833/stock.git'
$Root = $FixedRoot

function Normalize-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    try { return [IO.Path]::GetFullPath($Path) }
    catch { throw "Unable to resolve path safely: $Path" }
}

function Test-WithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath
    )
    $rootFull = (Normalize-FullPath $RootPath).TrimEnd('\')
    $pathFull = (Normalize-FullPath $Path).TrimEnd('\')
    return ($pathFull -ieq $rootFull -or $pathFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase))
}

function Assert-SafePath {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath
    )
    $full = Normalize-FullPath $Path
    if (-not (Test-WithinRoot -Path $full -RootPath $RootPath)) {
        throw "$Label path escapes the fixed install root: $full"
    }

    $cursor = $full
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "$Label path is a reparse point and is not accepted: $cursor"
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrEmpty($parent) -or $parent -ieq $cursor) { break }
        $cursor = $parent
    }

    if (Test-Path -LiteralPath $full) {
        try {
            $resolved = Resolve-Path -LiteralPath $full -ErrorAction Stop | Select-Object -First 1
            $resolvedPath = if ($resolved.ProviderPath) { [string]$resolved.ProviderPath } else { [string]$resolved.Path }
            if (-not (Test-WithinRoot -Path $resolvedPath -RootPath $RootPath)) {
                throw "$Label path resolves outside the fixed install root: $resolvedPath"
            }
        }
        catch {
            if ($_.Exception.Message -like '*resolves outside the fixed install root*') { throw }
            throw "Unable to resolve $Label path safely: $full"
        }
    }
}

function Normalize-Origin {
    param([AllowNull()][string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $value = $Url.Trim().TrimEnd('/')
    if (-not $value.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
        $value += '.git'
    }
    return $value.ToLowerInvariant()
}

function Assert-GitDirFileSafe {
    param(
        [Parameter(Mandatory = $true)][string]$GitPath,
        [Parameter(Mandatory = $true)][string]$RootPath
    )
    if (-not (Test-Path -LiteralPath $GitPath -PathType Leaf)) { return }
    $line = Get-Content -LiteralPath $GitPath -TotalCount 1 -ErrorAction Stop
    if ($line -match '^\s*gitdir:\s*(.+?)\s*$') {
        $gitDir = $Matches[1].Trim()
        if (-not [IO.Path]::IsPathRooted($gitDir)) {
            $gitDir = Join-Path (Split-Path -Parent $GitPath) $gitDir
        }
        Assert-SafePath -Label '.git target' -Path $gitDir -RootPath $RootPath
    }
}

function Find-LocalGit {
    $command = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'),
        (Join-Path $env:ProgramFiles 'Git\bin\git.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\git.exe')
    )
    $desktopRoot = Join-Path $env:LOCALAPPDATA 'GitHubDesktop'
    if (Test-Path -LiteralPath $desktopRoot -PathType Container) {
        $candidates += @(Get-ChildItem -LiteralPath $desktopRoot -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName 'resources\app\git\cmd\git.exe' })
    }
    foreach ($candidate in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

try {
    if ($TestRoot) {
        if ($env:STOCK_SETUP_TEST_MODE -ne '1') {
            throw '-TestRoot is restricted to read-only test mode.'
        }
        $Root = Normalize-FullPath $TestRoot
    }

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "Fixed install root is missing or is not a directory: $Root"
    }

    Assert-SafePath -Label 'root' -Path $Root -RootPath $Root
    $gitDir = Join-Path $Root '.git'
    Assert-SafePath -Label '.git' -Path $gitDir -RootPath $Root
    if (-not (Test-Path -LiteralPath $gitDir)) {
        throw "Fixed install root is not a Git repository: $Root"
    }
    Assert-GitDirFileSafe -GitPath $gitDir -RootPath $Root

    $git = Find-LocalGit
    if (-not $git) { throw 'git.exe was not found; fixed-root identity cannot be verified.' }
    $origin = & $git -C $Root remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $origin) { throw "Git origin is missing: $Root" }
    $actual = ([string]($origin | Select-Object -Last 1)).Trim()
    if ((Normalize-Origin $actual) -ne (Normalize-Origin $ExpectedOrigin)) {
        throw "Git origin is not the approved fixed-root repository: $actual"
    }

    Write-Output "[OK] Fixed install root verified: $Root"
    Write-Output "[OK] Origin verified: $actual"
    exit 0
}
catch {
    Write-Output '[ERROR] Fixed install root verification failed; no changes were made.'
    Write-Output $_.Exception.Message
    exit 2
}
