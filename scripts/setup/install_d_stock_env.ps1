[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$Preflight,
    [switch]$DryRun,
    [switch]$ConfigureOnly,
    [switch]$SelfTest,
    [Parameter(DontShow = $true)]
    [string]$TestRoot,
    [Parameter(DontShow = $true)]
    [switch]$SimulateMissingGit,
    [Parameter(DontShow = $true)]
    [switch]$SimulateMissingPython,
    [Parameter(DontShow = $true)]
    [switch]$SimulateMissingWinget,
    [Parameter(DontShow = $true)]
    [switch]$ProbeWingetArgs,
    [Parameter(DontShow = $true)]
    [string]$TestWingetPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# The public installer is intentionally fixed to this tree.  TestRoot and the
# simulation switches are restricted to read-only test mode and are not used
# by the CMD entrypoints.
$SharedRoot = 'D:\stock'
$InstallRoot = 'D:\stock\GitHub'
if ($SelfTest -and $TestRoot) {
    $InstallRoot = [IO.Path]::GetFullPath($TestRoot)
    $SharedRoot = Split-Path -Parent $InstallRoot
}
$RepoUrl = 'https://github.com/week833/stock.git'
$LegacyRoot = 'D:\Downloads\stock'
$script:ReadOnly = ($Preflight -or $DryRun)
$script:LogFile = Join-Path $env:TEMP 'install_d_stock_env.log'
$script:ProbeWingetArgs = $ProbeWingetArgs
$script:TestWingetPath = $TestWingetPath
if ($TestRoot) {
    if ($env:STOCK_SETUP_TEST_MODE -ne '1' -or (-not $script:ReadOnly -and -not $ProbeWingetArgs)) {
        throw '-TestRoot is restricted to read-only test mode.'
    }
    $InstallRoot = [IO.Path]::GetFullPath($TestRoot)
    $SharedRoot = Split-Path -Parent $InstallRoot
}

function Write-Status {
    param(
        [AllowEmptyString()][string]$Message = '',
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
    if (-not $script:ReadOnly -and $script:LogFile) {
        $Message | Add-Content -LiteralPath $script:LogFile -Encoding UTF8
    }
}

function Normalize-RepoUrl {
    param([AllowNull()][string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $value = $Url.Trim().TrimEnd('/')
    if ($value.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
        $value = $value.Substring(0, $value.Length - 4)
    }
    return $value.ToLowerInvariant()
}

function Test-ExpectedOrigin {
    param([AllowNull()][string]$Origin)
    return ((Normalize-RepoUrl $Origin) -eq (Normalize-RepoUrl $RepoUrl))
}

function Find-CommandPath {
    param([Parameter(Mandatory = $true)][string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Find-Git {
    $found = Find-CommandPath -Name 'git.exe'
    if ($found) { return $found }
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
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function Test-SupportedPython {
    param([Parameter(Mandatory = $true)][string]$PythonPath)
    try {
        $raw = & $PythonPath -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) { return $false }
        $version = [version](([string]($raw | Select-Object -Last 1)).Trim())
        return ($version -ge [version]'3.10.0' -and $version -lt [version]'3.13.0')
    }
    catch { return $false }
}

function Find-Python {
    $launcher = Find-CommandPath -Name 'py.exe'
    if ($launcher) {
        foreach ($selector in @('-3.12', '-3.11', '-3.10')) {
            try {
                $result = & $launcher $selector -c "import sys; print(sys.executable)" 2>$null
                if ($LASTEXITCODE -eq 0 -and $result) {
                    $candidate = ([string]($result | Select-Object -Last 1)).Trim()
                    if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and (Test-SupportedPython $candidate)) {
                        return $candidate
                    }
                }
            }
            catch { }
        }
    }

    $candidates = @()
    $pythonCommand = Find-CommandPath -Name 'python.exe'
    if ($pythonCommand) { $candidates += $pythonCommand }
    $candidates += @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python310\python.exe')
    )
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf) -and (Test-SupportedPython $candidate)) {
            return $candidate
        }
    }
    return $null
}

function Find-Winget {
    if ($script:ProbeWingetArgs -and $script:TestWingetPath) {
        return $script:TestWingetPath
    }
    return (Find-CommandPath -Name 'winget.exe')
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$AllowFailure
    )
    Write-Status ("> {0} {1}" -f $FilePath, ($Arguments -join ' ')) ([ConsoleColor]::DarkGray)
    if ($script:ReadOnly) {
        Write-Status '  [DRY-RUN] command not executed.' ([ConsoleColor]::DarkYellow)
        return 0
    }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previous }
    if ($null -ne $output) {
        foreach ($line in $output) {
            ([string]$line) | Write-Host
            if ($script:LogFile) { ([string]$line) | Add-Content -LiteralPath $script:LogFile -Encoding UTF8 }
        }
    }
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "Command failed with exit code ${exitCode}: $FilePath"
    }
    return $exitCode
}

function Invoke-CmdScript {
    param([Parameter(Mandatory = $true)][string]$ScriptPath)
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Required CMD script was not found: $ScriptPath"
    }
    Invoke-Native -FilePath $env:ComSpec -Arguments @('/d', '/c', "call `"$ScriptPath`"")
}

function Install-WithWinget {
    param([Parameter(Mandatory = $true)][string]$PackageId, [Parameter(Mandatory = $true)][string]$DisplayName)
    $winget = Find-Winget
    if (-not $winget) {
        throw "$DisplayName is missing and winget is unavailable. Install $DisplayName offline, then rerun this installer."
    }
    Write-Status "[INSTALL] $DisplayName via fixed winget id $PackageId" ([ConsoleColor]::Yellow)
    Invoke-Native -FilePath $winget -Arguments @(
        'install', '--id', $PackageId, '-e', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements',
        '--silent', '--disable-interactivity'
    )
}

function Get-ChildItemCount {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    return @((Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)).Count
}

function Get-NormalizedFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return [IO.Path]::GetFullPath($Path)
    }
    catch {
        throw "Unable to resolve managed path: $Path"
    }
}

function Test-PathWithinInstallRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )
    $rootFull = (Get-NormalizedFullPath -Path $Root).TrimEnd('\')
    $pathFull = (Get-NormalizedFullPath -Path $Path).TrimEnd('\')
    return ($pathFull -ieq $rootFull -or $pathFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase))
}

function Assert-TestPathNoReparse {
    param([Parameter(Mandatory = $true)][string]$Path)
    $cursor = Get-NormalizedFullPath -Path $Path
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "Test path is a reparse point and is not accepted: $cursor"
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrEmpty($parent) -or $parent -ieq $cursor) { break }
        $cursor = $parent
    }
}

function Assert-CriticalPathsSafe {
    $rootFull = Get-NormalizedFullPath -Path $InstallRoot
    $critical = [ordered]@{
        root = $rootFull
        git = Join-Path $rootFull '.git'
        venv = Join-Path $rootFull '.venv'
        scripts = Join-Path $rootFull 'scripts'
        sources = Join-Path $rootFull 'repos'
        requirements = Join-Path $rootFull 'requirements.txt'
        marker = Join-Path $rootFull '.stock-install-marker'
    }

    foreach ($entry in $critical.GetEnumerator()) {
        $label = [string]$entry.Key
        $candidate = Get-NormalizedFullPath -Path ([string]$entry.Value)
        if (-not (Test-PathWithinInstallRoot -Path $candidate -Root $rootFull)) {
            throw "Managed $label path escapes the fixed install root: $candidate"
        }

        # Check every existing ancestor so a junction/symlink above a managed
        # child cannot redirect Git, venv, scripts, or requirements elsewhere.
        $cursor = $candidate
        while ($cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
            if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw "Managed $label path is a reparse point and is not accepted: $cursor"
            }
            $parent = Split-Path -Parent $cursor
            if ([string]::IsNullOrEmpty($parent) -or $parent -ieq $cursor) { break }
            $cursor = $parent
        }

        if (Test-Path -LiteralPath $candidate) {
            try {
                $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction Stop | Select-Object -First 1
                $resolvedPath = if ($resolved.ProviderPath) { [string]$resolved.ProviderPath } else { [string]$resolved.Path }
                if (-not (Test-PathWithinInstallRoot -Path $resolvedPath -Root $rootFull)) {
                    throw "Managed $label path resolves outside the fixed install root: $resolvedPath"
                }
            }
            catch {
                if ($_.Exception.Message -like 'Managed *path resolves outside*') { throw }
                throw "Unable to resolve managed $label path safely: $candidate"
            }
        }

        if ($label -eq 'git' -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $gitLine = Get-Content -LiteralPath $candidate -TotalCount 1 -ErrorAction Stop
            if ($gitLine -match '^\s*gitdir:\s*(.+?)\s*$') {
                $gitDir = $Matches[1].Trim()
                if (-not [IO.Path]::IsPathRooted($gitDir)) {
                    $gitDir = Join-Path (Split-Path -Parent $candidate) $gitDir
                }
                $gitDirFull = Get-NormalizedFullPath -Path $gitDir
                if (-not (Test-PathWithinInstallRoot -Path $gitDirFull -Root $rootFull)) {
                    throw "Managed git metadata resolves outside the fixed install root: $gitDirFull"
                }
            }
        }
    }
}

function Get-RepositoryState {
    param([AllowNull()][string]$GitPath, [Parameter(Mandatory = $true)][string]$Path)

    $result = [ordered]@{
        Exists = (Test-Path -LiteralPath $Path -PathType Container)
        NonEmpty = $false
        HasGit = $false
        Origin = ''
        Branch = ''
        Dirty = $false
        ValidOrigin = $false
        StatusText = ''
        Error = ''
    }
    if (-not $result.Exists) { return [pscustomobject]$result }
    $result.NonEmpty = ((Get-ChildItemCount -Path $Path) -gt 0)
    $result.HasGit = (Test-Path -LiteralPath (Join-Path $Path '.git'))
    if (-not $result.HasGit) { return [pscustomobject]$result }
    if (-not $GitPath) {
        $result.Error = 'git.exe is required to inspect the existing repository.'
        return [pscustomobject]$result
    }

    try {
        $origin = & $GitPath -C $Path remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $origin) { $result.Origin = ([string]($origin | Select-Object -Last 1)).Trim() }
        $branch = & $GitPath -C $Path branch --show-current 2>$null
        if ($LASTEXITCODE -eq 0 -and $branch) { $result.Branch = ([string]($branch | Select-Object -Last 1)).Trim() }
        if (-not $result.Branch) { $result.Branch = 'HEAD' }
        $status = & $GitPath -C $Path status --porcelain --untracked-files=all 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'git status failed' }
        $result.StatusText = (($status -join "`n").Trim())
        $result.Dirty = -not [string]::IsNullOrWhiteSpace($result.StatusText)
        $result.ValidOrigin = Test-ExpectedOrigin -Origin $result.Origin
    }
    catch {
        $result.Error = $_.Exception.Message
    }
    return [pscustomobject]$result
}

function Assert-InstallRootSafe {
    param([Parameter(Mandatory = $true)][AllowNull()]$GitPath)
    Assert-CriticalPathsSafe
    if (-not (Test-Path -LiteralPath $InstallRoot)) {
        Write-Status "[PLAN] Create install root: $InstallRoot" ([ConsoleColor]::Cyan)
        return
    }
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        throw "Install root is not a directory: $InstallRoot"
    }

    $state = Get-RepositoryState -GitPath $GitPath -Path $InstallRoot
    if ($state.HasGit) {
        if ($state.Error) {
            if ($script:ReadOnly -and -not $GitPath) {
                Write-Status '[PLAN] Existing repository will be verified after Git.Git is available; no command will run in preflight.' ([ConsoleColor]::Cyan)
                return
            }
            throw $state.Error
        }
        if (-not $state.ValidOrigin) {
            throw "Install root has an unexpected origin ('$($state.Origin)'). Nothing was changed."
        }
        if ($state.Dirty) {
            Write-Status '[KEEP] Existing dirty repository detected; self-update will be skipped.' ([ConsoleColor]::Yellow)
        }
        elseif ($state.Branch -ne 'main') {
            Write-Status "[KEEP] Existing branch '$($state.Branch)' is not main; self-update will be skipped." ([ConsoleColor]::Yellow)
        }
        else {
            Write-Status '[PLAN] Clean main repository may fast-forward from the pinned origin.' ([ConsoleColor]::Cyan)
        }
        return
    }

    if ((Get-ChildItemCount -Path $InstallRoot) -gt 0) {
        throw "Install root is non-empty and is not the expected repository. Nothing was moved or deleted: $InstallRoot"
    }
    Write-Status "[PLAN] Clone pinned repository into empty root: $InstallRoot" ([ConsoleColor]::Cyan)
}

function Merge-UniquePathEntries {
    param(
        [AllowNull()][string]$CurrentPath,
        [Parameter(Mandatory = $true)][string[]]$Entries
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $managedComparisons = @(
        foreach ($entry in @($Entries)) {
            $candidate = [string]$entry
            $comparison = $candidate.Trim().TrimEnd('\')
            if ($comparison) { $comparison }
        }
    )
    $seenManaged = New-Object 'System.Collections.Generic.List[string]'

    if (-not [string]::IsNullOrEmpty($CurrentPath)) {
        foreach ($item in @($CurrentPath -split ';')) {
            $candidate = [string]$item
            $comparison = $candidate.Trim().TrimEnd('\')
            $managedMatch = @($managedComparisons | Where-Object { $_ -ieq $comparison })
            if ($managedMatch.Count -gt 0) {
                $alreadyManaged = @($seenManaged | Where-Object { $_ -ieq $managedMatch[0] })
                if ($alreadyManaged.Count -eq 0) {
                    $parts.Add($candidate)
                    $seenManaged.Add($managedMatch[0])
                }
            }
            else {
                # Preserve every non-managed PATH segment verbatim, including
                # duplicates and its original order.
                $parts.Add($candidate)
            }
        }
    }
    foreach ($entry in @($Entries)) {
        $candidate = [string]$entry
        $comparison = $candidate.Trim().TrimEnd('\')
        if ($comparison) {
            $alreadyManaged = @($seenManaged | Where-Object { $_ -ieq $comparison })
            if ($alreadyManaged.Count -eq 0) {
                $parts.Add($candidate)
                $seenManaged.Add($comparison)
            }
        }
    }
    return @($parts)
}

function Add-UniquePathEntries {
    param([Parameter(Mandatory = $true)][string[]]$Entries)
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $merged = @(Merge-UniquePathEntries -CurrentPath $current -Entries $Entries)
    if ($script:ReadOnly) {
        Write-Status "[PLAN] User PATH keeps existing entries and adds: $($Entries -join '; ')" ([ConsoleColor]::Cyan)
        return
    }
    [Environment]::SetEnvironmentVariable('Path', ($merged -join ';'), 'User')
}

function Set-StockEnvironment {
    param([Parameter(Mandatory = $true)][string]$VenvDir, [Parameter(Mandatory = $true)][string]$VenvPython)
    $values = [ordered]@{
        STOCK_HOME = $InstallRoot
        STOCK_REPO = $InstallRoot
        STOCK_SHARED_ROOT = $SharedRoot
        STOCK_VENV = $VenvDir
        STOCK_PYTHON = $VenvPython
        STOCK_EXTERNAL_REPOS = (Join-Path $InstallRoot 'repos')
        PYTHONUTF8 = '1'
        PYTHONIOENCODING = 'utf-8'
    }
    if ($script:ReadOnly) {
        Write-Status '[PLAN] User environment variables will be set (no write in dry-run):' ([ConsoleColor]::Cyan)
        foreach ($name in $values.Keys) { Write-Status "       $name=$($values[$name])" ([ConsoleColor]::DarkGray) }
    }
    else {
        foreach ($name in $values.Keys) {
            [Environment]::SetEnvironmentVariable($name, [string]$values[$name], 'User')
            Set-Item -Path "Env:$name" -Value ([string]$values[$name])
        }
    }
    Add-UniquePathEntries -Entries @(
        $InstallRoot,
        (Join-Path $VenvDir 'Scripts'),
        (Join-Path $InstallRoot 'scripts'),
        (Join-Path $InstallRoot 'scripts\setup'),
        (Join-Path $InstallRoot 'scripts\sources'),
        (Join-Path $InstallRoot 'scripts\compat')
    )
    if (-not $script:ReadOnly) {
        $env:STOCK_HOME = $InstallRoot
        $env:STOCK_REPO = $InstallRoot
        $env:STOCK_SHARED_ROOT = $SharedRoot
        $env:STOCK_VENV = $VenvDir
        $env:STOCK_PYTHON = $VenvPython
        $env:STOCK_EXTERNAL_REPOS = Join-Path $InstallRoot 'repos'
        $env:PYTHONUTF8 = '1'
        $env:PYTHONIOENCODING = 'utf-8'
    }
}

function Test-Venv {
    param([Parameter(Mandatory = $true)][string]$VenvPython)
    if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) { return $false }
    try {
        & $VenvPython -c "import sys; print(sys.executable)" *> $null
        return ($LASTEXITCODE -eq 0)
    }
    catch { return $false }
}

function Write-Preflight {
    param([AllowNull()]$Git, [AllowNull()]$Python, [AllowNull()]$Winget, [Parameter(Mandatory = $true)]$State)
    $venvDir = Join-Path $InstallRoot '.venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'
    Write-Status ''
    Write-Status '---------------- Stock installer preflight ----------------' ([ConsoleColor]::Cyan)
    Write-Status "root=$InstallRoot"
    Write-Status "origin=$($State.Origin)"
    Write-Status "branch=$($State.Branch)"
    Write-Status "dirty=$($State.Dirty)"
    Write-Status "nonempty=$($State.NonEmpty)"
    Write-Status "git=$([bool]$Git)"
    Write-Status "python=$([bool]$Python)$(if($Python){' (' + $Python + ')' }else{''})"
    Write-Status "winget=$([bool]$Winget)"
    Write-Status "venv=$venvPython (exists=$([bool](Test-Path -LiteralPath $venvPython)))"
    Write-Status 'path_plan=preserve existing user PATH; add only stock root/venv/scripts entries'
    Write-Status ("source_plan=download only when explicitly selected ({0})" -f (Join-Path $InstallRoot 'repos'))
    if ($State.Dirty) { Write-Status 'self_update=skip because repository is dirty' ([ConsoleColor]::Yellow) }
    elseif ($State.Branch -and $State.Branch -ne 'main') { Write-Status 'self_update=skip because branch is not main' ([ConsoleColor]::Yellow) }
    else { Write-Status 'self_update=fast-forward only on a clean main repository' ([ConsoleColor]::Cyan) }
    Write-Status '-------------------------------------------------------------' ([ConsoleColor]::Cyan)
}

function Run-SelfTest {
    $temp = Join-Path $env:TEMP ('stock-installer-selftest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    try {
        $script:ReadOnly = $true
        if (-not (Test-ExpectedOrigin $RepoUrl)) { throw 'origin normalization self-test failed' }
        if (Test-ExpectedOrigin 'https://example.invalid/stock.git') { throw 'unexpected origin accepted' }
        $managed = @(
            'D:\stock\GitHub',
            'D:\stock\GitHub\.venv\Scripts',
            'D:\stock\GitHub\scripts',
            'D:\stock\GitHub\scripts\setup',
            'D:\stock\GitHub\scripts\sources',
            'D:\stock\GitHub\scripts\compat'
        )
        foreach ($pathCase in @('', 'C:\one', 'C:\one;C:\two', 'C:\one;C:\one')) {
            $merged = @(Merge-UniquePathEntries -CurrentPath $pathCase -Entries $managed)
            $expectedExisting = @($pathCase -split ';' | Where-Object { $_ })
            if ($merged.Count -ne ($expectedExisting.Count + $managed.Count)) {
                throw "PATH merge count self-test failed for '$pathCase'."
            }
            for ($i = 0; $i -lt $expectedExisting.Count; $i++) {
                if ($merged[$i] -cne $expectedExisting[$i]) {
                    throw "PATH existing-entry order self-test failed for '$pathCase'."
                }
            }
            $again = @(Merge-UniquePathEntries -CurrentPath ($merged -join ';') -Entries $managed)
            if (($again -join ';') -cne ($merged -join ';')) {
                throw "PATH idempotency self-test failed for '$pathCase'."
            }
        }
        $duplicates = @(
            'D:\stock\GitHub',
            'd:\STOCK\GITHUB\',
            'D:\stock\GitHub\scripts\setup',
            'D:\stock\GitHub\scripts\setup\'
        ) -join ';'
        $deduped = @(Merge-UniquePathEntries -CurrentPath $duplicates -Entries $managed)
        if (@($deduped | Where-Object { $_.Trim().TrimEnd('\') -ieq 'd:\stock\github' }).Count -ne 1) {
            throw 'PATH managed duplicate self-test failed.'
        }
        $file = Join-Path $temp 'unrelated.txt'
        'KEEP' | Set-Content -LiteralPath $file -Encoding ASCII
        if ((Get-ChildItemCount -Path $temp) -ne 1) { throw 'safe path self-test failed' }
        Write-Status '[SELFTEST] Safe origin, path and dry-run helpers passed.' ([ConsoleColor]::Green)
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

function Ensure-Repository {
    param([Parameter(Mandatory = $true)][AllowNull()]$Git)
    Assert-InstallRootSafe -GitPath $Git
    $state = Get-RepositoryState -GitPath $Git -Path $InstallRoot
    if ($script:ReadOnly) { return $state }

    if (-not $state.Exists -or (-not $state.HasGit -and -not $state.NonEmpty)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $InstallRoot) -Force | Out-Null
        Invoke-Native -FilePath $Git -Arguments @('clone', $RepoUrl, $InstallRoot)
        return (Get-RepositoryState -GitPath $Git -Path $InstallRoot)
    }
    if ($state.HasGit -and $state.ValidOrigin -and -not $state.Dirty -and $state.Branch -eq 'main') {
        # A clean main tree may only receive a fast-forward from the pinned
        # origin; user branches and local changes are always left untouched.
        Invoke-Native -FilePath $Git -Arguments @('-C', $InstallRoot, 'fetch', '--prune', 'origin')
        Invoke-Native -FilePath $Git -Arguments @('-C', $InstallRoot, 'pull', '--ff-only', 'origin', 'main')
    }
    return (Get-RepositoryState -GitPath $Git -Path $InstallRoot)
}

function Assert-RepositoryReadyForVenv {
    param([Parameter(Mandatory = $true)][AllowNull()]$Git)

    Assert-CriticalPathsSafe
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        throw "Install root was not created: $InstallRoot"
    }
    $state = Get-RepositoryState -GitPath $Git -Path $InstallRoot
    if (-not $state.HasGit -or -not $state.ValidOrigin) {
        throw "Cloned repository identity could not be verified before venv creation: $InstallRoot"
    }
    if ($state.Error) { throw $state.Error }
    foreach ($relative in @(
            'requirements.txt', 'scripts', 'scripts\setup', 'scripts\sources', 'scripts\compat',
            'scripts\setup\assert_fixed_install_root.ps1',
            'scripts\compat\verify_stock_environment.cmd',
            'scripts\compat\verify_python_packages.py',
            'scripts\sources\source_manifest_v1.json')) {
        $path = Join-Path $InstallRoot $relative
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Required repository path is missing before venv creation: $path"
        }
        Assert-TestPathNoReparse -Path $path
    }
    if (Test-Path -LiteralPath (Join-Path $InstallRoot '.stock-install-marker')) {
        throw 'A .stock-install-marker is not an install identity and cannot bypass repository verification.'
    }
    return $state
}

try {
    if ($SelfTest) {
        Run-SelfTest
        exit 0
    }
    if ($ProbeWingetArgs) {
        if ($env:STOCK_SETUP_TEST_MODE -ne '1' -or [string]::IsNullOrWhiteSpace($TestRoot) -or
            [string]::IsNullOrWhiteSpace($TestWingetPath)) {
            throw '-ProbeWingetArgs is restricted to STOCK_SETUP_TEST_MODE=1 with -TestRoot and -TestWingetPath.'
        }
        $tempRoot = (Get-NormalizedFullPath -Path ([IO.Path]::GetTempPath())).TrimEnd('\')
        $testRootFull = (Get-NormalizedFullPath -Path $TestRoot).TrimEnd('\')
        $wingetPathFull = (Get-NormalizedFullPath -Path $TestWingetPath).TrimEnd('\')
        if (-not (Test-PathWithinInstallRoot -Path $testRootFull -Root $tempRoot)) {
            throw "-TestRoot must be a TEMP fixture path: $TestRoot"
        }
        if (-not (Test-Path -LiteralPath $testRootFull -PathType Container)) {
            throw "-TestRoot fixture directory was not found: $TestRoot"
        }
        if (-not (Test-PathWithinInstallRoot -Path $wingetPathFull -Root $testRootFull)) {
            throw "-TestWingetPath must be inside the TEMP test root: $TestWingetPath"
        }
        Assert-TestPathNoReparse -Path $testRootFull
        Assert-TestPathNoReparse -Path $wingetPathFull
        $script:LogFile = Join-Path $testRootFull '.winget-probe.log'
        if (-not (Test-Path -LiteralPath $wingetPathFull -PathType Leaf)) {
            throw "Test winget command was not found: $TestWingetPath"
        }
        Install-WithWinget -PackageId 'Git.Git' -DisplayName 'Git for Windows'
        Install-WithWinget -PackageId 'Python.Python.3.12' -DisplayName 'Python 3.12'
        Write-Status '[SELFTEST] Winget argument contract passed.' ([ConsoleColor]::Green)
        exit 0
    }
    if (-not $script:ReadOnly) {
        "============================================================" | Set-Content -LiteralPath $script:LogFile -Encoding UTF8
        "Stock toolkit installation started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -LiteralPath $script:LogFile -Encoding UTF8
    }

    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status ' Stock Toolkit Installer - Safe Mode' ([ConsoleColor]::Cyan)
    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status "Install root: $InstallRoot"
    if ($script:ReadOnly) { Write-Status '[READ-ONLY] No repository, venv, PATH, registry or package changes will be made.' ([ConsoleColor]::Yellow) }

    $git = if ($SimulateMissingGit) { $null } else { Find-Git }
    $python = if ($SimulateMissingPython) { $null } else { Find-Python }
    $winget = if ($SimulateMissingWinget) { $null } else { Find-Winget }
    Assert-CriticalPathsSafe
    $state = Get-RepositoryState -GitPath $git -Path $InstallRoot
    Write-Preflight -Git $git -Python $python -Winget $winget -State $state

    if ($state.HasGit -and -not $git) {
        if (-not $winget) {
            throw 'Existing repository found but git.exe is missing and winget is unavailable; install Git for Windows manually, then retry.'
        }
        if ($script:ReadOnly) {
            Write-Status '[PLAN] Git.Git would be installed before verifying the existing repository origin (no install in preflight).' ([ConsoleColor]::Cyan)
        }
        else {
            Install-WithWinget -PackageId 'Git.Git' -DisplayName 'Git for Windows'
            $env:Path = "$env:ProgramFiles\Git\cmd;$env:LOCALAPPDATA\Programs\Git\cmd;$env:Path"
            $git = Find-Git
            if (-not $git) { throw 'git.exe was not found after the fixed winget installation.' }
            $state = Get-RepositoryState -GitPath $git -Path $InstallRoot
            if ($state.Error) { throw $state.Error }
        }
    }
    if ($state.Exists -and -not $state.HasGit -and $state.NonEmpty) {
        throw "Install root is non-empty and has no expected Git repository: $InstallRoot"
    }
    # Validate the target before any winget install or other formal mutation.
    Assert-InstallRootSafe -GitPath $git
    if (-not $git -and -not $winget) { throw 'Git is missing and winget is unavailable; install Git for Windows manually, then retry.' }
    if (-not $python -and -not $winget) { throw 'Supported Python 3.10-3.12 is missing and winget is unavailable; install Python 3.12 manually, then retry.' }
    if ($ConfigureOnly -and -not $state.Exists) { throw "Install root does not exist: $InstallRoot" }
    if ($ConfigureOnly -and -not (Test-Path -LiteralPath (Join-Path $InstallRoot 'requirements.txt') -PathType Leaf)) {
        throw "Not a stock repository (requirements.txt missing): $InstallRoot"
    }

    if ($Preflight -or $DryRun) {
        Assert-CriticalPathsSafe
        if (-not $python) { Write-Status '[PLAN] Python 3.12 would be installed with winget id Python.Python.3.12.' ([ConsoleColor]::Cyan) }
        if (-not $git) { Write-Status '[PLAN] Git would be installed with winget id Git.Git.' ([ConsoleColor]::Cyan) }
        if (-not $winget -and (-not $git -or -not $python)) { throw 'winget is unavailable for a required missing prerequisite.' }
        if ($ConfigureOnly -and -not (Test-Path -LiteralPath (Join-Path $InstallRoot '.venv\Scripts\python.exe') -PathType Leaf)) {
            throw 'Virtual environment is missing; dry-run did not create it.'
        }
        Write-Status '[OK] Preflight completed without writes.' ([ConsoleColor]::Green)
        exit 0
    }

    if (-not (Test-Path -LiteralPath $SharedRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $SharedRoot -Force | Out-Null
    }
    if (-not $git) {
        Install-WithWinget -PackageId 'Git.Git' -DisplayName 'Git for Windows'
        $env:Path = "$env:ProgramFiles\Git\cmd;$env:LOCALAPPDATA\Programs\Git\cmd;$env:Path"
        $git = Find-Git
        if (-not $git) { throw 'git.exe was not found after the fixed winget installation.' }
    }
    if (-not $python) {
        Install-WithWinget -PackageId 'Python.Python.3.12' -DisplayName 'Python 3.12'
        $env:Path = "$env:LOCALAPPDATA\Programs\Python\Python312;$env:LOCALAPPDATA\Programs\Python\Python312\Scripts;$env:LOCALAPPDATA\Programs\Python\Launcher;$env:Path"
        $python = Find-Python
        if (-not $python) { throw 'A supported Python 3.10-3.12 executable was not found after installation.' }
    }

    if (-not $ConfigureOnly) {
        Write-Status '[1/5] Checking repository root and self-update policy...' ([ConsoleColor]::White)
        $state = Ensure-Repository -Git $git
    }
    else {
        Write-Status '[1/3] Keeping the existing repository; configure-only mode never updates Git.' ([ConsoleColor]::White)
        $state = Get-RepositoryState -GitPath $git -Path $InstallRoot
    }

    # Re-run identity, critical-path, reparse and required-file checks after a
    # clone/update and before touching the virtual environment.  A marker file
    # or a partial tree can never authorize venv creation.
    $state = Assert-RepositoryReadyForVenv -Git $git

    $venvDir = Join-Path $InstallRoot '.venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'
    Write-Status "[$(if($ConfigureOnly){'2/3'}else{'2/5'})] Checking Python virtual environment..." ([ConsoleColor]::White)
    if (Test-Path -LiteralPath $venvDir -PathType Container) {
        if (-not (Test-Venv -VenvPython $venvPython)) {
            throw "Managed virtual environment is incomplete or invalid: $venvDir. Nothing was moved or deleted."
        }
    }
    else {
        Invoke-Native -FilePath $python -Arguments @('-m', 'venv', $venvDir)
    }
    if (-not (Test-Venv -VenvPython $venvPython)) { throw "Virtual environment could not be validated: $venvPython" }

    if (-not $ConfigureOnly) {
        Write-Status '[3/5] Installing requirements into the managed venv...' ([ConsoleColor]::White)
        $requirements = Join-Path $InstallRoot 'requirements.txt'
        if (-not (Test-Path -LiteralPath $requirements -PathType Leaf)) { throw "requirements.txt was not found: $requirements" }
        Invoke-Native -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel')
        Invoke-Native -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '-r', $requirements)
    }

    Write-Status "[$(if($ConfigureOnly){'3/3'}else{'4/5'})] Configuring user environment and PATH..." ([ConsoleColor]::White)
    Set-StockEnvironment -VenvDir $venvDir -VenvPython $venvPython

    if (-not $ConfigureOnly) {
        Write-Status '[5/5] Verifying the managed environment...' ([ConsoleColor]::White)
        Invoke-Native -FilePath $venvPython -Arguments @('-c', "import sys, pandas, numpy, requests, yfinance; print(sys.executable); print('D_STOCK_ENV_OK')")
        if ($Full) {
            Write-Status '[INFO] Source download is a separate menu operation; no source script was invoked by the environment core.' ([ConsoleColor]::DarkYellow)
        }
        else { Write-Status '[INFO] Source downloads were not selected.' ([ConsoleColor]::DarkYellow) }
    }

    Write-Status ''
    Write-Status '[OK] Stock toolkit operation completed.' ([ConsoleColor]::Green)
    Write-Status "Install root: $InstallRoot"
    Write-Status "Python: $venvPython"
    Write-Status 'No unrelated D:\stock files were moved, deleted or renamed.'
    exit 0
}
catch {
    Write-Status ''
    Write-Status '[ERROR] Operation stopped safely; no unrelated files were moved or deleted.' ([ConsoleColor]::Red)
    Write-Status $_.Exception.Message ([ConsoleColor]::Red)
    if ($script:LogFile -and -not $script:ReadOnly) { Write-Status "Log: $script:LogFile" ([ConsoleColor]::Yellow) }
    if ($script:ReadOnly -or $script:ProbeWingetArgs) { exit 2 } else { exit 1 }
}
