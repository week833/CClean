[CmdletBinding()]
param(
    [switch]$Full
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$InstallRoot = 'D:\stock'
$LegacyRoot = 'D:\Downloads\stock'
$RepoUrl = 'https://github.com/week833/stock.git'
$LogFile = Join-Path $env:TEMP 'install_d_stock_env.log'

"============================================================" | Set-Content -LiteralPath $LogFile -Encoding UTF8
"D:\stock installation started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -LiteralPath $LogFile -Encoding UTF8
"============================================================" | Add-Content -LiteralPath $LogFile -Encoding UTF8

function Write-Status {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
    $Message | Add-Content -LiteralPath $LogFile -Encoding UTF8
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    Write-Status ("> {0} {1}" -f $FilePath, ($Arguments -join ' ')) ([ConsoleColor]::DarkGray)
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($null -ne $output) {
        $output | ForEach-Object {
            Write-Host $_
            $_ | Out-File -LiteralPath $LogFile -Append -Encoding UTF8
        }
    }

    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $FilePath"
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-Git {
    $command = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Test-SupportedPython {
    param(
        [Parameter(Mandatory = $true)][string]$PythonPath
    )

    try {
        $raw = & $PythonPath -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) {
            return $false
        }

        $versionText = ([string]($raw | Select-Object -Last 1)).Trim()
        $version = [version]$versionText
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
    if ($pythonCommand) {
        $candidates += $pythonCommand.Source
    }

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
    Invoke-External -FilePath $winget.Source -Arguments @(
        'install',
        '--id',
        $PackageId,
        '-e',
        '--source',
        'winget',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )
}

function Add-UserPathEntries {
    param(
        [Parameter(Mandatory = $true)][string[]]$Entries
    )

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

        if (-not $exists) {
            $parts += $entry
        }
    }

    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
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
        $item = Get-Item -LiteralPath $LinkPath -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Write-Status "[KEEP] Existing junction: $LinkPath" ([ConsoleColor]::DarkYellow)
            return
        }

        $children = @(Get-ChildItem -LiteralPath $LinkPath -Force -ErrorAction SilentlyContinue)
        if ($children.Count -eq 0) {
            Remove-Item -LiteralPath $LinkPath -Force
        }
        else {
            Write-Status "[WARN] Existing non-empty path was not replaced: $LinkPath" ([ConsoleColor]::Yellow)
            return
        }
    }

    try {
        New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath -Force | Out-Null
        Write-Status "[LINK] $LinkPath -> $TargetPath" ([ConsoleColor]::Green)
    }
    catch {
        Write-Status "[WARN] Junction creation failed: $($_.Exception.Message)" ([ConsoleColor]::Yellow)
    }
}

try {
    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status ' D:\stock Stock Toolkit Installer' ([ConsoleColor]::Cyan)
    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status "Install root: $InstallRoot"
    Write-Status "Repository: $RepoUrl"
    Write-Status "Log file: $LogFile"
    Write-Status ''

    if (-not (Test-Path -LiteralPath 'D:\')) {
        throw 'Drive D: was not found.'
    }

    if (-not (Test-IsAdministrator)) {
        Write-Status '[WARN] The installer is not running as administrator.' ([ConsoleColor]::Yellow)
        Write-Status '[WARN] User environment setup can continue, but junction creation may fail.' ([ConsoleColor]::Yellow)
    }

    Write-Status '[1/8] Checking Git...' ([ConsoleColor]::White)
    $git = Find-Git
    if (-not $git) {
        Install-WithWinget -PackageId 'Git.Git' -DisplayName 'Git for Windows'
        $env:Path = "$env:ProgramFiles\Git\cmd;$env:LOCALAPPDATA\Programs\Git\cmd;$env:Path"
        $git = Find-Git
    }

    if (-not $git) {
        throw 'git.exe was not found after installation.'
    }

    Write-Status "[OK] Git: $git" ([ConsoleColor]::Green)

    Write-Status '[2/8] Checking Python 3.10 through 3.12...' ([ConsoleColor]::White)
    $python = Find-Python
    if (-not $python) {
        Install-WithWinget -PackageId 'Python.Python.3.12' -DisplayName 'Python 3.12'
        $env:Path = "$env:LOCALAPPDATA\Programs\Python\Python312;$env:LOCALAPPDATA\Programs\Python\Python312\Scripts;$env:LOCALAPPDATA\Programs\Python\Launcher;$env:Path"
        $python = Find-Python
    }

    if (-not $python) {
        throw 'A supported Python 3.10 through 3.12 executable was not found.'
    }

    Write-Status "[OK] Python: $python" ([ConsoleColor]::Green)

    Write-Status '[3/8] Creating or updating D:\stock...' ([ConsoleColor]::White)
    $gitDir = Join-Path $InstallRoot '.git'

    if (Test-Path -LiteralPath $gitDir) {
        $originOutput = & $git -C $InstallRoot remote get-url origin 2>$null
        $origin = ([string]($originOutput | Select-Object -Last 1)).Trim()

        if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'week833/stock') {
            throw "D:\stock is another Git repository. Current origin: $origin"
        }

        Invoke-External -FilePath $git -Arguments @('-C', $InstallRoot, 'fetch', '--prune')
        Invoke-External -FilePath $git -Arguments @('-C', $InstallRoot, 'checkout', 'main')
        Invoke-External -FilePath $git -Arguments @('-C', $InstallRoot, 'pull', '--ff-only', 'origin', 'main')
    }
    else {
        if (Test-Path -LiteralPath $InstallRoot) {
            $existingItems = @(Get-ChildItem -LiteralPath $InstallRoot -Force -ErrorAction SilentlyContinue)

            if ($existingItems.Count -gt 0) {
                $backupRoot = "D:\stock_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Write-Status "[BACKUP] Moving existing non-Git folder to $backupRoot" ([ConsoleColor]::Yellow)
                Move-Item -LiteralPath $InstallRoot -Destination $backupRoot
            }
            else {
                Remove-Item -LiteralPath $InstallRoot -Force
            }
        }

        Invoke-External -FilePath $git -Arguments @('clone', $RepoUrl, $InstallRoot)
    }

    Write-Status '[4/8] Creating or repairing the Python virtual environment...' ([ConsoleColor]::White)
    $venvDir = Join-Path $InstallRoot '.venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'
    $venvIsValid = $false

    if (Test-Path -LiteralPath $venvPython) {
        & $venvPython -c "import sys; print(sys.executable)" *> $null
        if ($LASTEXITCODE -eq 0) {
            $venvIsValid = $true
        }
    }

    if (-not $venvIsValid) {
        if (Test-Path -LiteralPath $venvDir) {
            Write-Status '[REPAIR] Removing an invalid virtual environment.' ([ConsoleColor]::Yellow)
            Remove-Item -LiteralPath $venvDir -Recurse -Force
        }

        Invoke-External -FilePath $python -Arguments @('-m', 'venv', $venvDir)
    }

    Invoke-External -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel')
    Invoke-External -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '-r', (Join-Path $InstallRoot 'requirements.txt'))

    Write-Status '[5/8] Configuring user environment variables and PATH...' ([ConsoleColor]::White)
    $environmentVariables = @{
        STOCK_HOME = $InstallRoot
        STOCK_REPO = $InstallRoot
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
        (Join-Path $InstallRoot '.venv\Scripts'),
        (Join-Path $InstallRoot 'scripts'),
        (Join-Path $InstallRoot 'scripts\setup'),
        (Join-Path $InstallRoot 'scripts\sources'),
        (Join-Path $InstallRoot 'scripts\compat')
    )

    Add-UserPathEntries -Entries $pathEntries
    $env:Path = (($pathEntries -join ';') + ';' + $env:Path)

    Write-Status '[6/8] Creating the legacy D:\Downloads\stock junction...' ([ConsoleColor]::White)
    Ensure-LegacyJunction -LinkPath $LegacyRoot -TargetPath $InstallRoot

    $env:STOCK_TOOLKIT_NO_PAUSE = '1'
    $repairScript = Join-Path $InstallRoot 'scripts\compat\repair_legacy_paths.cmd'
    if (Test-Path -LiteralPath $repairScript) {
        Invoke-External -FilePath $repairScript
    }

    Write-Status '[7/8] Verifying the core environment...' ([ConsoleColor]::White)
    Invoke-External -FilePath $venvPython -Arguments @(
        '-c',
        "import sys, FinMind, twstock, pandas, numpy, requests, yfinance, matplotlib, openpyxl; print(sys.executable); print('D_STOCK_ENV_OK')"
    )

    if ($Full) {
        Write-Status '[8/8] Downloading all primary and legacy research repositories...' ([ConsoleColor]::White)

        $sourceScript = Join-Path $InstallRoot 'scripts\sources\clone_stock_analysis_repos.cmd'
        if (-not (Test-Path -LiteralPath $sourceScript)) {
            throw "Source downloader was not found: $sourceScript"
        }

        Invoke-External -FilePath $sourceScript

        $legacySourceScript = Join-Path $InstallRoot 'scripts\sources\clone_legacy_compat_repos.cmd'
        if (Test-Path -LiteralPath $legacySourceScript) {
            Invoke-External -FilePath $legacySourceScript
        }

        if (Test-Path -LiteralPath $repairScript) {
            Invoke-External -FilePath $repairScript
        }
    }
    else {
        Write-Status '[8/8] Large external repositories were skipped.' ([ConsoleColor]::DarkYellow)
        Write-Status '      Run DOWNLOAD_STOCK_SOURCES.cmd when they are needed.' ([ConsoleColor]::DarkYellow)
    }

    Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue

    Write-Status ''
    Write-Status '============================================================' ([ConsoleColor]::Green)
    Write-Status ' Installation and environment configuration completed' ([ConsoleColor]::Green)
    Write-Status '============================================================' ([ConsoleColor]::Green)
    Write-Status "Install root: $InstallRoot"
    Write-Status "Python: $venvPython"
    Write-Status "Legacy path: $LegacyRoot -> $InstallRoot"
    Write-Status 'Restart CMD, PowerShell, VS Code, Task Scheduler, and other applications to load the updated user PATH.'
    exit 0
}
catch {
    Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue
    Write-Status ''
    Write-Status '[ERROR] Installation failed.' ([ConsoleColor]::Red)
    Write-Status $_.Exception.Message ([ConsoleColor]::Red)
    ($_ | Format-List * -Force | Out-String) | Add-Content -LiteralPath $LogFile -Encoding UTF8
    Write-Status "Review the log file: $LogFile" ([ConsoleColor]::Yellow)
    exit 1
}
