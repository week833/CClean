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
        throw "Command failed with exit code $exitCode: $FilePath"
    }
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
        $raw = & $PythonPath -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $raw) { return $false }
        $version = [version]([string]($raw | Select-Object -Last 1)).Trim()
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
    Invoke-External -FilePath $winget.Source -Arguments @(
        'install', '--id', $PackageId, '-e', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements'
    )
}

function Add-UserPathEntries {
    param([string[]]$Entries)
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

try {
    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status ' D:\stock 台股工具完整安裝程式（穩定版）' ([ConsoleColor]::Cyan)
    Write-Status '============================================================' ([ConsoleColor]::Cyan)
    Write-Status "正式安裝位置：$InstallRoot"
    Write-Status "GitHub：$RepoUrl"
    Write-Status "紀錄檔：$LogFile"
    Write-Status ''

    if (-not (Test-Path -LiteralPath 'D:\')) {
        throw '找不到 D: 磁碟機。'
    }

    Write-Status '[1/8] 檢查 Git...' ([ConsoleColor]::White)
    $git = Find-Git
    if (-not $git) {
        Install-WithWinget -PackageId 'Git.Git' -DisplayName 'Git for Windows'
        $env:Path = "$env:ProgramFiles\Git\cmd;$env:LOCALAPPDATA\Programs\Git\cmd;$env:Path"
        $git = Find-Git
    }
    if (-not $git) { throw 'Git 安裝後仍無法找到 git.exe。' }
    Write-Status "[OK] Git：$git" ([ConsoleColor]::Green)

    Write-Status '[2/8] 檢查 Python 3.10–3.12...' ([ConsoleColor]::White)
    $python = Find-Python
    if (-not $python) {
        Install-WithWinget -PackageId 'Python.Python.3.12' -DisplayName 'Python 3.12'
        $env:Path = "$env:LOCALAPPDATA\Programs\Python\Python312;$env:LOCALAPPDATA\Programs\Python\Python312\Scripts;$env:LOCALAPPDATA\Programs\Python\Launcher;$env:Path"
        $python = Find-Python
    }
    if (-not $python) { throw 'Python 3.10–3.12 安裝後仍無法找到可用的 python.exe。' }
    Write-Status "[OK] Python：$python" ([ConsoleColor]::Green)

    Write-Status '[3/8] 建立或更新 D:\stock repository...' ([ConsoleColor]::White)
    $gitDir = Join-Path $InstallRoot '.git'
    if (Test-Path -LiteralPath $gitDir) {
        $originOutput = & $git -C $InstallRoot remote get-url origin 2>$null
        $origin = ([string]($originOutput | Select-Object -Last 1)).Trim()
        if ($LASTEXITCODE -ne 0 -or $origin -notmatch 'week833/stock') {
            throw "D:\stock 已是其他 Git repository，origin=$origin。為避免覆蓋，安裝已停止。"
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
                Write-Status "[BACKUP] 既有非 Git 資料夾移至 $backupRoot" ([ConsoleColor]::Yellow)
                Move-Item -LiteralPath $InstallRoot -Destination $backupRoot
            }
            else {
                Remove-Item -LiteralPath $InstallRoot -Force
            }
        }
        Invoke-External -FilePath $git -Arguments @('clone', $RepoUrl, $InstallRoot)
    }

    Write-Status '[4/8] 建立 / 修復 Python 虛擬環境...' ([ConsoleColor]::White)
    $venvDir = Join-Path $InstallRoot '.venv'
    $venvPython = Join-Path $venvDir 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPython)) {
        Invoke-External -FilePath $python -Arguments @('-m', 'venv', $venvDir)
    }
    Invoke-External -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel')
    Invoke-External -FilePath $venvPython -Arguments @('-m', 'pip', 'install', '-r', (Join-Path $InstallRoot 'requirements.txt'))

    Write-Status '[5/8] 設定 Windows 使用者環境變數與 PATH...' ([ConsoleColor]::White)
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

    Write-Status '[6/8] 建立 D:\Downloads\stock 舊路徑相容連結...' ([ConsoleColor]::White)
    $legacyParent = Split-Path -Parent $LegacyRoot
    if (-not (Test-Path -LiteralPath $legacyParent)) {
        New-Item -ItemType Directory -Path $legacyParent -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $LegacyRoot)) {
        try {
            New-Item -ItemType Junction -Path $LegacyRoot -Target $InstallRoot -Force | Out-Null
            Write-Status "[LINK] $LegacyRoot -> $InstallRoot" ([ConsoleColor]::Green)
        }
        catch {
            Write-Status "[WARN] 無法建立舊路徑 junction：$($_.Exception.Message)" ([ConsoleColor]::Yellow)
            Write-Status '       核心環境仍可使用；舊程式請改用 D:\stock，或以系統管理員身分重跑。' ([ConsoleColor]::Yellow)
        }
    }
    else {
        Write-Status "[KEEP] 舊路徑已存在：$LegacyRoot" ([ConsoleColor]::DarkYellow)
    }

    $env:STOCK_TOOLKIT_NO_PAUSE = '1'
    $repairScript = Join-Path $InstallRoot 'scripts\compat\repair_legacy_paths.cmd'
    if (Test-Path -LiteralPath $repairScript) {
        Invoke-External -FilePath $repairScript
    }

    Write-Status '[7/8] 驗證核心環境...' ([ConsoleColor]::White)
    Invoke-External -FilePath $venvPython -Arguments @(
        '-c',
        "import sys, FinMind, twstock, pandas, numpy, requests, yfinance, matplotlib, openpyxl; print(sys.executable); print('D_STOCK_ENV_OK')"
    )

    if ($Full) {
        Write-Status '[8/8] 下載 / 更新全部外部研究來源...' ([ConsoleColor]::White)
        $sourceScript = Join-Path $InstallRoot 'scripts\sources\clone_stock_analysis_repos.cmd'
        Invoke-External -FilePath $sourceScript
    }
    else {
        Write-Status '[8/8] 略過大型外部來源下載。需要時執行 DOWNLOAD_STOCK_SOURCES.cmd。' ([ConsoleColor]::DarkYellow)
    }

    Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue
    Write-Status ''
    Write-Status '============================================================' ([ConsoleColor]::Green)
    Write-Status ' 安裝與環境設定完成' ([ConsoleColor]::Green)
    Write-Status '============================================================' ([ConsoleColor]::Green)
    Write-Status "正式路徑：$InstallRoot"
    Write-Status "Python：$venvPython"
    Write-Status "舊路徑：$LegacyRoot -> $InstallRoot"
    Write-Status '請關閉後重新開啟 CMD、PowerShell、VS Code、排程器或其他應用程式，讓新的 PATH 生效。'
    exit 0
}
catch {
    Remove-Item Env:STOCK_TOOLKIT_NO_PAUSE -ErrorAction SilentlyContinue
    Write-Status ''
    Write-Status '[ERROR] 安裝流程失敗。' ([ConsoleColor]::Red)
    Write-Status $_.Exception.Message ([ConsoleColor]::Red)
    ($_ | Format-List * -Force | Out-String) | Add-Content -LiteralPath $LogFile -Encoding UTF8
    Write-Status "請查看紀錄：$LogFile" ([ConsoleColor]::Yellow)
    exit 1
}
