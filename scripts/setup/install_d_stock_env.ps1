[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$SelfTest
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$global:LASTEXITCODE = 0

$SharedRoot = 'D:\stock'
$InstallRoot = 'D:\stock\GitHub'
$LegacyRoot = 'D:\Downloads\stock'
$RepoUrl = 'https://github.com/week833/stock.git'
$LogFile = Join-Path $env:TEMP 'install_d_stock_env.log'

"============================================================" | Set-Content -LiteralPath $LogFile -Encoding UTF8
"Stock toolkit installation started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -LiteralPath $LogFile -Encoding UTF8
"============================================================" | Add-Content -LiteralPath $LogFile -Encoding UTF8

function Write-Status {
    param(
        [AllowEmptyString()]
        [string]$Message = '',
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
    $Message | Add-Content -LiteralPath $LogFile -Encoding UTF8
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    Write-Status ("> {0} {1}" -f $FilePath, ($Arguments -join ' ')) ([ConsoleColor]::DarkGray)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $FilePath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($null -ne $output) {
        foreach ($line in $output) {
            Write-Host $line
            ([string]$line) | Out-File -LiteralPath $LogFile -Append -Encoding UTF8
        }
    }

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath"
    }
}

function Invoke-CmdScript {
    param([Parameter(Mandatory = $true)][string]$ScriptPath)

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Required CMD script was not found: $ScriptPath"
    }

    Invoke-Native -FilePath $env:ComSpec -Arguments @('/d', '/c', "call `"$ScriptPath`"")
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-Git {
    $command = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
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
    catch {
        return $false
    }
}

function Find-Python {
    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcher) {
        foreach ($selector in @('-3.12', '-3.11', '-3.10')) {
            $result = & $launcher.Source $selector -c "import sys; print(sys.executable)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $result) {
                $candidate = ([string]($result | Select-Object -Last 1)).Trim()
                if ((Test-Path -LiteralPath $candidate) -and (Test-SupportedPython -PythonPath $candidate)) {
                    return $candidate
                }
            }
        }
    }

    $candidates = @()
    $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($pythonCommand) { $candidates += $pythonCommand.Source }
    $candidates += @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python311\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python310\python.exe')
    )

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path -LiteralPath $candidate) -and (Test-SupportedPython -PythonPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Install-WithWinget {
    param(
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$DisplayName
    )

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "$DisplayName is missing and winget is unavailable."
    }

    Write-Status "[INSTALL] Installing $DisplayName with winget..." ([ConsoleColor]::Yellow)
    Invoke-Native -FilePath $winget.Source -Arguments @(
        'install', '--id', $PackageId, '-e', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements'
    )
}

function Add-UserPathEntries {
    param([Parameter(Mandatory = $true)][string[]]$Entries)

    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if ($current) {
        $parts = @($current -split ';' | Where-Object { $_ -and $_.Trim() })
    }

    foreach ($entry in $Entries) {
        $exists = $false
        foreach ($part in $parts) {
            if ($part.TrimEnd('\') -ieq $entry.TrimEnd('\')) {
                $exists = $true
                break
            }
        }
        if (-not $exists) { $parts += $entry }
    }

    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

function Get-RepositoryOrigin {
    param(
        [Parameter(Mandatory = $true)][string]$GitPath,
        [Parameter(Mandatory = $true)][string]$RepositoryPath
    )

    if (-not (Test-Path -LiteralPath (Join-Path $RepositoryPath '.git'))) { return $null }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $GitPath -C $RepositoryPath remote get-url origin 2>$null
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($exitCode -ne 0 -or -not $output) { return $null }
    return ([string]($output | Select-Object -Last 1)).Trim()
}

function Test-ExpectedRepository {
    param(
        [Parameter(Mandatory = $true)][string]$GitPath,
        [Parameter(Mandatory = $true)][string]$RepositoryPath
    )

    $origin = Get-RepositoryOrigin -GitPath $GitPath -RepositoryPath $RepositoryPath
    return ($origin -and $origin -match 'week833/stock(?:\.git)?$')
}

function Test-DirectoryEmpty {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $true }
    return (@(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Count -eq 0)
}

function Ensure-LegacyJunction {
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $parent = Split-Path -Parent $LinkPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $LinkPath) {
        Write-Status "[KEEP] Existing legacy path was not modified: $LinkPath" ([ConsoleColor]::DarkYellow)
        return
    }

    try {
        New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath -Force | Out-Null
        Write-Status "[LINK] $LinkPath -> $TargetPath" ([ConsoleColor]::Green)
    }
    catch {
        Write-Status "[WARN] Junction creation failed: $($_.Exception.Message)" ([ConsoleColor]::Yellow)
    }
}

function Report-PreviousBackups {
    $backups = @(Get-ChildItem -LiteralPath 'D:\' -Directory -Filter 'stock_backup_*' -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($backups.Count -eq 0) { return }

    $reportPath = Join-Path $SharedRoot 'PREVIOUS_INSTALLER_BACKUPS.txt'
    $lines = @(
        'Previous installer backup folders were found.',
        'No backup folder was changed by this installer.',
        'Run RECOVER_MOVED_STOCK_PROGRAMS.cmd to copy their contents into a recovery folder.',
        ''
    )
    $lines += $backups.FullName
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8

    Write-Status '[WARN] Previous installer backup folders were found.' ([ConsoleColor]::Yellow)
    Write-Status "       Report: $reportPath" ([ConsoleColor]::Yellow)
}

if ($SelfTest) {
    Write-Status ''
    Write-Status '[SELFTEST] Empty status messages are accepted.' ([ConsoleColor]::Green)

    $testRoot = Join-Path $env:TEMP ("stock_safe_root_{0}" -f [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    try {
        'KEEP_ME' | Set-Content -LiteralPath (Join-Path $testRoot 'unrelated_program.txt') -Encoding ASCII
        $testInstall = Join-Path $testRoot 'GitHub'
        if ($testInstall -ne (Join-Path $testRoot 'GitHub')) { throw 'Install path self-test failed.' }
        if (-not (Test-Path -LiteralPath (Join-Path $testRoot 'unrelated_program.txt'))) {
            throw 'Unrelated file preservation self-test failed.'
        }
    }
    finally {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $testExitCode = 7
    $testText = "Command failed with exit code ${testExitCode}: self-test"
    if ($testText -notmatch 'exit code 7') { throw 'Message formatting self-test failed.' }

    Write-Status '[SELFTEST] Safe path and runtime checks passed.' ([ConsoleColor]::Green)
    exit 0
}

try {
    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status ' Stock Toolkit Installer - Safe Mode' ([ConsoleColor]::Cyan)
    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status "Shared folder: $SharedRoot"
    Write-Status "Install folder: $InstallRoot"
    Write-Status "Repository: $RepoUrl"
    Write-Status "Log file: $LogFile"
    Write-Status ''

    if (-not (Test-Path -LiteralPath 'D:\')) { throw 'Drive D: was not found.' }
    if (-not (Test-IsAdministrator)) {
        Write-Status '[WARN] Administrator privileges were not detected.' ([ConsoleColor]::Yellow)
    }

    if (-not (Test-Path -LiteralPath $SharedRoot)) {
        New-Item -ItemType Directory -Path $SharedRoot -Force | Out-Null
    }

    Report-PreviousBackups

    Write-Status '[1/8] Checking Git...' ([ConsoleColor]::White)
    $git = Find-Git
    if (-not $git) {
        Install-WithWinget -PackageId 'Git.Git' -DisplayName 'Git for Windows'
        $env:Path = "$env:ProgramFiles\Git\cmd;$env:LOCALAPPDATA\Programs\Git\cmd;$env:Path"
        $git = Find-Git
    }
    if (-not $git) { throw 'git.exe was not found after installation.' }
    Write-Status "[OK] Git: $git" ([ConsoleColor]::Green)

    Write-Status '[2/8] Checking Python 3.10 through 3.12...' ([ConsoleColor]::White)
    $python = Find-Python
    if (-not $python) {
        Install-WithWinget -PackageId 'Python.Python.3.12' -DisplayName 'Python 3.12'
        $env:Path = "$env:LOCALAPPDATA\Programs\Python\Python312;$env:LOCALAPPDATA\Programs\Python\Python312\Scripts;$env:LOCALAPPDATA\Programs\Python\Launcher;$env:Path"
        $python = Find-Python
    }
    if (-not $python) { throw 'A supported Python 3.10 through 3.12 executable was not found.' }
    Write-Status "[OK] Python: $python" ([ConsoleColor]::Green)

    Write-Status '[3/8] Creating or updating the repository safely...' ([ConsoleColor]::White)
    Write-Status '[SAFE] Existing files directly under D:\stock will not be moved, deleted, or renamed.' ([ConsoleColor]::Green)

    if (Test-ExpectedRepository -GitPath $git -RepositoryPath $InstallRoot) {
        $trackedChanges = & $git -C $InstallRoot status --porcelain --untracked-files=no
        if ($LASTEXITCODE -ne 0) { throw "Unable to inspect repository status: $InstallRoot" }
        if ($trackedChanges) {
            Write-Status '[WARN] Tracked local changes exist. Git update was skipped.' ([ConsoleColor]::Yellow)
        }
        else {
            Invoke-Native -FilePath $git -Arguments @('-C', $InstallRoot, 'fetch', '--prune')
            Invoke-Native -FilePath $git -Arguments @('-C', $InstallRoot, 'checkout', 'main')
            Invoke-Native -FilePath $git -Arguments @('-C', $InstallRoot, 'pull', '--ff-only', 'origin', 'main')
        }
    }
    else {
        if (Test-Path -LiteralPath $InstallRoot) {
            if (-not (Test-DirectoryEmpty -Path $InstallRoot)) {
                throw "D:\stock\GitHub already contains other files. Nothing was moved or deleted. Clear or rename only that subfolder, then run the installer again."
            }
        }
        Invoke-Native -FilePath $git -Arguments @('clone', $RepoUrl, $InstallRoot)
    }

    Write-Status '[4/8] Creating or repairing the Python virtual environment...' ([ConsoleColor]::White)
    $venvDir = Join-Path $InstallRoot '.venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'

    if (Test-Path -LiteralPath $venvDir) {
        if (-not (Test-Path -LiteralPath $venvPython)) {
            throw "The managed virtual environment is incomplete: $venvDir. It was not moved or deleted. Rename only this .venv folder and run again."
        }
        & $venvPython -c "import sys; print(sys.executable)" *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "The managed virtual environment is invalid: $venvDir. It was not moved or deleted. Rename only this .venv folder and run again."
        }
    }
    else {
        Invoke-Native -FilePath $python -Arguments @('-m', 'venv', $venvDir)
    }

    Invoke-Native -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel')
    Invoke-Native -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '-r', (Join-Path $InstallRoot 'requirements.txt'))

    Write-Status '[5/8] Configuring user environment variables and PATH...' ([ConsoleColor]::White)
    $environmentVariables = @{
        STOCK_HOME = $InstallRoot
        STOCK_REPO = $InstallRoot
        STOCK_SHARED_ROOT = $SharedRoot
        STOCK_VENV = $venvDir
        STOCK_PYTHON = $venvPython
        STOCK_EXTERNAL_REPOS = (Join-Path $InstallRoot 'external_repos')
        PYTHONUTF8 = '1'
        PYTHONIOENCODING = 'utf-8'
    }
    foreach ($name in $environmentVariables.Keys) {
        [Environment]::SetEnvironmentVariable($name, $environmentVariables[$name], 'User')
        Set-Item -Path "Env:$name" -Value $environmentVariables[$name]
    }

    $pathEntries = @(
        $InstallRoot,
        (Join-Path $venvDir 'Scripts'),
        (Join-Path $InstallRoot 'scripts'),
        (Join-Path $InstallRoot 'scripts\setup'),
        (Join-Path $InstallRoot 'scripts\sources'),
        (Join-Path $InstallRoot 'scripts\compat')
    )
    Add-UserPathEntries -Entries $pathEntries
    $env:Path = (($pathEntries -join ';') + ';' + $env:Path)

    Write-Status '[6/8] Creating the optional legacy path junction...' ([ConsoleColor]::White)
    Ensure-LegacyJunction -LinkPath $LegacyRoot -TargetPath $InstallRoot

    $env:STOCK_TOOLKIT_NO_PAUSE = '1'
    $repairScript = Join-Path $InstallRoot 'scripts\compat\repair_legacy_paths.cmd'
    if (Test-Path -LiteralPath $repairScript) { Invoke-CmdScript -ScriptPath $repairScript }

    Write-Status '[7/8] Verifying the core environment...' ([ConsoleColor]::White)
    Invoke-Native -FilePath $venvPython -Arguments @(
        '-c',
        "import sys, FinMind, twstock, pandas, numpy, requests, yfinance, matplotlib, openpyxl; print(sys.executable); print('D_STOCK_ENV_OK')"
    )

    if ($Full) {
        Write-Status '[8/8] Downloading all primary, large, and legacy research repositories...' ([ConsoleColor]::White)
        Invoke-CmdScript -ScriptPath (Join-Path $InstallRoot 'scripts\sources\clone_stock_analysis_repos.cmd')
        $legacySourceScript = Join-Path $InstallRoot 'scripts\sources\clone_legacy_compat_repos.cmd'
        if (Test-Path -LiteralPath $legacySourceScript) { Invoke-CmdScript -ScriptPath $legacySourceScript }
        if (Test-Path -LiteralPath $repairScript) { Invoke-CmdScript -ScriptPath $repairScript }
    }
    else {
        Write-Status '[8/8] Large external repositories were skipped.' ([ConsoleColor]::DarkYellow)
    }

    Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue
    Write-Status ''
    Write-Status '============================================================' ([ConsoleColor]::Green)
    Write-Status ' Installation completed without modifying unrelated programs' ([ConsoleColor]::Green)
    Write-Status '============================================================' ([ConsoleColor]::Green)
    Write-Status "Install root: $InstallRoot"
    Write-Status "Python: $venvPython"
    Write-Status "Shared folder preserved: $SharedRoot"
    Write-Status "Legacy path: $LegacyRoot"
    Write-Status 'Restart applications to load the updated user PATH.'
    exit 0
}
catch {
    Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue
    Write-Status ''
    Write-Status '[ERROR] Installation failed safely. Unrelated files were not moved or deleted.' ([ConsoleColor]::Red)
    Write-Status $_.Exception.Message ([ConsoleColor]::Red)
    ($_ | Format-List * -Force | Out-String) | Add-Content -LiteralPath $LogFile -Encoding UTF8
    Write-Status "Review the log file: $LogFile" ([ConsoleColor]::Yellow)
    exit 1
}
