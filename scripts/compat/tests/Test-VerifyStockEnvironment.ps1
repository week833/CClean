[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$verifier = Join-Path $testRoot 'scripts\compat\verify_stock_environment.cmd'
$helper = Join-Path $testRoot 'scripts\compat\verify_python_packages.py'
$fixedRootHelper = Join-Path $testRoot 'scripts\setup\assert_fixed_install_root.ps1'
$sourceManager = Join-Path $testRoot 'scripts\sources\source_manager.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('stock-verifier-fixture-' + [Guid]::NewGuid().ToString('N'))

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-FixtureSnapshot([string]$Root) {
    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($item in @(Get-ChildItem -LiteralPath $Root -Force -Recurse -ErrorAction Stop | Sort-Object FullName)) {
        $relative = $item.FullName.Substring($Root.Length).TrimStart('\')
        if ($item.PSIsContainer) {
            [void]$rows.Add("D|$relative|$($item.Attributes)")
        } else {
            $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
            [void]$rows.Add("F|$relative|$($item.Length)|$($item.Attributes)|$hash")
        }
    }
    return ($rows -join "`n")
}

function Invoke-CmdFixture([string]$Script, [hashtable]$Environment, [string]$WorkingDirectory) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = '/d /c call "' + $Script + '"'
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($key in $Environment.Keys) {
        $psi.EnvironmentVariables[$key] = [string]$Environment[$key]
    }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function Remove-FixtureJunction([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        & $env:ComSpec /d /c rmdir /q $Path | Out-Null
    }
}

try {
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    $dirs = @(
        '.git', '.venv', '.venv\Scripts', 'scripts', 'scripts\setup',
        'scripts\sources', 'scripts\compat', 'repos'
    )
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Path (Join-Path $fixture $dir) -Force | Out-Null
    }
    Copy-Item -LiteralPath $helper -Destination (Join-Path $fixture 'scripts\compat\verify_python_packages.py') -Force
    Copy-Item -LiteralPath $fixedRootHelper -Destination (Join-Path $fixture 'scripts\setup\assert_fixed_install_root.ps1') -Force
    Copy-Item -LiteralPath $sourceManager -Destination (Join-Path $fixture 'scripts\sources\source_manager.ps1') -Force

    $primary = New-Object System.Collections.Generic.List[object]
    [void]$primary.Add(@('taiwan_market_data\twstock', 'https://github.com/mlouielu/twstock.git'))
    $categories = @('taiwan_market_data', 'global_market_data', 'machine_learning_forecasting', 'backtesting_engines', 'quant_portfolio_risk')
    for ($i = 1; $i -le 36; $i++) {
        $category = $categories[($i - 1) % $categories.Count]
        [void]$primary.Add(@("$category\fixture-primary-$i", "https://github.com/example/fixture-primary-$i.git"))
    }
    $legacy = @(
        @('taiwan_market_data\twstock', 'https://github.com/mlouielu/twstock.git'),
        @('legacy_compat\fixture-legacy-one', 'https://github.com/example/fixture-legacy-one.git'),
        @('legacy_compat\fixture-legacy-two', 'https://github.com/example/fixture-legacy-two.git')
    )

    New-Item -ItemType File -Path (Join-Path $fixture '.git\config') -Force | Out-Null
    Write-Utf8NoBom (Join-Path $fixture '.origin') "https://github.com/week833/stock.git`r`n"
    $materialized = @('taiwan_market_data\twstock', 'taiwan_market_data\fixture-primary-1', 'global_market_data\fixture-primary-2', 'legacy_compat\fixture-legacy-one')
    $primaryLines = @('@echo off')
    foreach ($spec in $primary) {
        $relative = [string]$spec[0]
        $origin = [string]$spec[1]
        if ($materialized -contains $relative) {
            $target = Join-Path (Join-Path $fixture 'repos') $relative
            New-Item -ItemType Directory -Path (Join-Path $target '.git') -Force | Out-Null
            Write-Utf8NoBom (Join-Path $target '.origin') ($origin + "`r`n")
        }
        $primaryLines += ('call :clone_or_pull "' + $relative + '" "' + $origin + '"')
    }
    Write-Utf8NoBom (Join-Path $fixture 'scripts\sources\clone_stock_analysis_repos.cmd') (($primaryLines -join "`r`n") + "`r`n")

    $legacyLines = @('@echo off')
    foreach ($spec in $legacy) {
        $relative = [string]$spec[0]
        $origin = [string]$spec[1]
        if ($materialized -contains $relative) {
            $target = Join-Path (Join-Path $fixture 'repos') $relative
            New-Item -ItemType Directory -Path (Join-Path $target '.git') -Force | Out-Null
            Write-Utf8NoBom (Join-Path $target '.origin') ($origin + "`r`n")
        }
        $legacyLines += ('call :clone_or_pull "' + $relative + '" "' + $origin + '"')
    }
    Write-Utf8NoBom (Join-Path $fixture 'scripts\sources\clone_legacy_compat_repos.cmd') (($legacyLines -join "`r`n") + "`r`n")

    $manifestSources = @()
    for ($i = 0; $i -lt $primary.Count; $i++) {
        $spec = $primary[$i]
        $sourceId = if ($i -eq 0) { 'twstock' } else { "fixture-primary-$($i + 1)" }
        $manifestSources += [ordered]@{
            id = $sourceId
            scope = 'primary'
            default_install = ($i -lt 3)
            category = ([string]$spec[0]).Split('\')[0]
            target = [string]$spec[0]
            url = [string]$spec[1]
            expected_branch = 'main'
            estimated_bytes = 1
            usage = 'fixture'
            license_note = 'fixture'
        }
    }
    $manifestSources += [ordered]@{
        id = 'fixture-legacy-one'; scope = 'legacy'; default_install = $false; category = 'legacy_compat'; target = 'legacy_compat\fixture-legacy-one'; url = 'https://github.com/example/fixture-legacy-one.git'; expected_branch = 'main'; estimated_bytes = 1; usage = 'fixture'; license_note = 'fixture'
    }
    $manifestSources += [ordered]@{
        id = 'fixture-legacy-two'; scope = 'legacy'; default_install = $false; category = 'legacy_compat'; target = 'legacy_compat\fixture-legacy-two'; url = 'https://github.com/example/fixture-legacy-two.git'; expected_branch = 'main'; estimated_bytes = 1; usage = 'fixture'; license_note = 'fixture'
    }
    $manifest = [ordered]@{
        schema_version = 1
        sources = $manifestSources
        legacy_aliases = @(
            [ordered]@{ id = 'legacy_twstock_alias'; source_id = 'twstock'; purpose = 'Fixture shared primary twstock clone.' }
        )
    }
    Write-Utf8NoBom (Join-Path $fixture 'scripts\sources\source_manifest_v1.json') ($manifest | ConvertTo-Json -Depth 8)

    $wrapperLines = @(
        '@echo off',
        'if /I "%STOCK_VERIFY_WRAPPER_MODE%"=="fail" (echo fixture source verification failed&exit /b 7)',
        'echo fixture source verification passed',
        'exit /b 0'
    )
    $stockWrapper = Join-Path $fixture 'DOWNLOAD_STOCK_SOURCES.cmd'
    $legacyWrapper = Join-Path $fixture 'DOWNLOAD_LEGACY_SOURCES.cmd'
    Write-Utf8NoBom $stockWrapper (($wrapperLines -join "`r`n") + "`r`n")
    Write-Utf8NoBom $legacyWrapper (($wrapperLines -join "`r`n") + "`r`n")

    $requirements = @(
        'FinMind', 'twstock', 'requests', 'pandas', 'numpy', 'yfinance', 'feedparser', 'anthropic',
        'beautifulsoup4', 'lxml', 'html5lib', 'python-dotenv', 'matplotlib', 'exchange_calendars',
        'ta', 'pydantic', 'pyecharts', 'loguru', 'aiohttp', 'tqdm', 'pyarrow', 'openpyxl',
        'xlsxwriter', 'Jinja2', 'reportlab', 'python-dateutil', 'pytz', 'tzdata'
    )
    Write-Utf8NoBom (Join-Path $fixture 'requirements.txt') (($requirements -join "`r`n") + "`r`n")

    $fakeGit = Join-Path $fixture 'fake-git.cmd'
    $fakeGitLines = @(
        '@echo off', 'setlocal', 'if /I "%~3"=="remote" if /I "%~4"=="get-url" if /I "%~5"=="origin" (',
        '  type "%~2\.origin"', '  exit /b 0', ')', 'if /I "%~3"=="status" exit /b 0', 'exit /b 0'
    )
    Write-Utf8NoBom $fakeGit (($fakeGitLines -join "`r`n") + "`r`n")
    $fakePython = Join-Path $fixture '.venv\Scripts\python.cmd'
    $fakePythonLines = @(
        '@echo off',
        'if /I "%~1"=="--version" (echo Python 3.12.0&exit /b 0)',
        'if /I "%~1"=="-c" (echo 3.12.0&exit /b 0)',
        'if /I "%~1"=="-m" if /I "%~2"=="pip" if /I "%~3"=="--version" (echo pip 26.0 from fixture&exit /b 0)',
        'if /I "%~1"=="-m" if /I "%~2"=="pip" if /I "%~3"=="check" (echo No broken requirements found.&exit /b 0)',
        'if exist "%~1" (echo [SUMMARY] direct_requirements=28 failures=0&exit /b 0)',
        'exit /b 1'
    )
    Write-Utf8NoBom $fakePython (($fakePythonLines -join "`r`n") + "`r`n")

    $pathEntries = @(
        $fixture,
        (Join-Path $fixture '.venv\Scripts'),
        (Join-Path $fixture 'scripts'),
        (Join-Path $fixture 'scripts\setup'),
        (Join-Path $fixture 'scripts\sources'),
        (Join-Path $fixture 'scripts\compat')
    )
    $before = Get-FixtureSnapshot $fixture
    $envVars = @{
        STOCK_TOOLKIT_NO_PAUSE = '1'
        STOCK_VERIFY_TEST_MODE = '1'
        STOCK_VERIFY_ROOT = $fixture
        STOCK_VERIFY_GIT_EXE = $fakeGit
        STOCK_VERIFY_VENV_PYTHON = $fakePython
        STOCK_VERIFY_STOCK_WRAPPER = $stockWrapper
        STOCK_VERIFY_LEGACY_WRAPPER = $legacyWrapper
        STOCK_VERIFY_WRAPPER_MODE = 'success'
        STOCK_VERIFY_USER_PATH = ($pathEntries -join ';')
        STOCK_VERIFY_USER_VARS = @(
            "STOCK_HOME=$fixture",
            "STOCK_REPO=$fixture",
            "STOCK_SHARED_ROOT=$(Split-Path -Parent $fixture)",
            "STOCK_VENV=$(Join-Path $fixture '.venv')",
            "STOCK_PYTHON=$fakePython",
            "STOCK_EXTERNAL_REPOS=$(Join-Path $fixture 'repos')"
        ) -join ';'
        STOCK_VERIFY_EXPECTED_JUNCTIONS = '0'
        STOCK_VERIFY_SKIP_JUNCTIONS = '1'
        STOCK_VERIFY_SKIP_LEGACY_LINK = '1'
    }
    $result = Invoke-CmdFixture $verifier $envVars $fixture
    if ($result.ExitCode -ne 0) {
        throw "fixture verifier failed with exit code $($result.ExitCode)`n$($result.StdOut)`n$($result.StdErr)"
    }
    if ($result.StdOut -notmatch 'Primary source manifest identity count is 37') {
        $tail = (($result.StdOut -split "`n") | Select-Object -Last 12) -join "`n"
        throw "primary manifest identity assertion was not observed; exit=$($result.ExitCode) lines=$((($result.StdOut -split "`n").Count)) tail=`n$tail`n$($result.StdErr)"
    }
    if ($result.StdOut -notmatch 'Optional legacy source entries observed: 2') {
        throw 'legacy optional source assertion was not observed'
    }
    if ($result.StdOut -notmatch 'AI/Agent research sources are optional') {
        throw 'optional AI/Agent source notice was not observed'
    }
    if ($result.StdOut -notmatch 'fixture DOWNLOAD_STOCK_SOURCES.cmd --verify passed' -or
        $result.StdOut -notmatch 'fixture DOWNLOAD_LEGACY_SOURCES.cmd --verify passed') {
        throw 'fixture source wrapper success results were not observed'
    }

    $criticalPackageHelper = Join-Path $fixture 'scripts\compat\verify_python_packages.py'
    Remove-Item -LiteralPath $criticalPackageHelper -Force
    $missingCritical = Invoke-CmdFixture $verifier $envVars $fixture
    if ($missingCritical.ExitCode -eq 0 -or
        $missingCritical.StdOut -notmatch 'Critical Python package verifier' -or
        $missingCritical.StdOut -notmatch 'errors=[1-9][0-9]*') {
        throw "missing critical package verifier did not fail closed; exit=$($missingCritical.ExitCode)`n$($missingCritical.StdOut)`n$($missingCritical.StdErr)"
    }
    Copy-Item -LiteralPath $helper -Destination $criticalPackageHelper -Force

    $envVars['STOCK_VERIFY_WRAPPER_MODE'] = 'fail'
    $wrapperFailure = Invoke-CmdFixture $verifier $envVars $fixture
    if ($wrapperFailure.ExitCode -eq 0 -or $wrapperFailure.StdOut -notmatch 'returned exit code 7') {
        throw "source wrapper failure was not surfaced as a verifier error; exit=$($wrapperFailure.ExitCode)`n$($wrapperFailure.StdOut)"
    }
    $envVars['STOCK_VERIFY_WRAPPER_MODE'] = 'success'
    $manifestPath = Join-Path $fixture 'scripts\sources\source_manifest_v1.json'
    $manifestBaselineText = [IO.File]::ReadAllText($manifestPath)
    $maliciousUrlText = $manifestBaselineText.Replace(
        'https://github.com/mlouielu/twstock.git',
        'https://github.com/mlouielu/twstock.git/evil')
    Write-Utf8NoBom $manifestPath $maliciousUrlText
    $maliciousUrl = Invoke-CmdFixture $verifier $envVars $fixture
    if ($maliciousUrl.ExitCode -eq 0 -or $maliciousUrl.StdOut -notmatch 'source manifest contains unsafe identity fields') {
        throw "malicious manifest GitHub URL was accepted; exit=$($maliciousUrl.ExitCode)`n$($maliciousUrl.StdOut)`n$($maliciousUrl.StdErr)"
    }
    Write-Utf8NoBom $manifestPath $manifestBaselineText
    $invalidAliasObject = $manifestBaselineText | ConvertFrom-Json
    $invalidAliasObject.legacy_aliases[0].source_id = 'not-twstock'
    Write-Utf8NoBom $manifestPath ($invalidAliasObject | ConvertTo-Json -Depth 8)
    $invalidAlias = Invoke-CmdFixture $verifier $envVars $fixture
    if ($invalidAlias.ExitCode -eq 0 -or $invalidAlias.StdOut -notmatch 'legacy twstock alias are invalid') {
        throw "invalid legacy twstock alias was accepted; exit=$($invalidAlias.ExitCode)`n$($invalidAlias.StdOut)`n$($invalidAlias.StdErr)"
    }
    Write-Utf8NoBom $manifestPath $manifestBaselineText
    Write-Output '[OK] manifest GitHub URL regex: legal .git accepted; path-suffix attack rejected.'
    $after = Get-FixtureSnapshot $fixture
    if ($before -cne $after) {
        throw 'read-only verifier changed the fixture snapshot'
    }

    $rootOrigin = Join-Path $fixture '.origin'
    Write-Utf8NoBom $rootOrigin "https://github.com/example/wrong-origin.git`r`n"
    $wrongOrigin = Invoke-CmdFixture $verifier $envVars $fixture
    if ($wrongOrigin.ExitCode -eq 0 -or $wrongOrigin.StdOut -notmatch 'Git origin mismatch') {
        throw 'wrong-origin fixture did not fail closed'
    }
    Write-Utf8NoBom $rootOrigin "https://github.com/week833/stock.git`r`n"

    $gitMetadata = Join-Path $fixture '.git'
    Remove-Item -LiteralPath $gitMetadata -Recurse -Force
    Write-Utf8NoBom $gitMetadata "gitdir: C:\outside-verifier-test`r`n"
    $unsafeGit = Invoke-CmdFixture $verifier $envVars $fixture
    if ($unsafeGit.ExitCode -eq 0 -or $unsafeGit.StdOut -notmatch 'Git metadata is missing, external, or unsafe') {
        throw "external gitdir fixture did not fail closed; exit=$($unsafeGit.ExitCode)`n$($unsafeGit.StdOut)`n$($unsafeGit.StdErr)"
    }
    Remove-Item -LiteralPath $gitMetadata -Force
    New-Item -ItemType Directory -Path $gitMetadata -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $gitMetadata 'config') -Force | Out-Null

    $junctionSupported = $true
    $insideTarget = Join-Path $fixture 'repos\junction-target'
    $insideLink = Join-Path $fixture 'scripts\setup\junction-inside'
    try {
        New-Item -ItemType Directory -Path $insideTarget -Force | Out-Null
        New-Item -ItemType Junction -Path $insideLink -Target $insideTarget -Force | Out-Null
    } catch {
        $junctionSupported = $false
        Write-Warning 'Junction creation is unavailable; junction target probes were skipped.'
    }
    if ($junctionSupported) {
        $criticalSetupPath = Join-Path $fixture 'scripts\setup'
        $criticalReparseTarget = Join-Path ([IO.Path]::GetTempPath()) ('stock-verifier-critical-reparse-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $criticalReparseTarget -Force | Out-Null
        Write-Utf8NoBom (Join-Path $criticalReparseTarget 'assert_fixed_install_root.ps1') '# fixture reparse target'
        Remove-Item -LiteralPath $criticalSetupPath -Recurse -Force
        New-Item -ItemType Junction -Path $criticalSetupPath -Target $criticalReparseTarget -Force | Out-Null
        $criticalReparse = Invoke-CmdFixture $verifier $envVars $fixture
        if ($criticalReparse.ExitCode -eq 0 -or $criticalReparse.StdOut -notmatch 'Critical fixed-root helper' -or $criticalReparse.StdOut -notmatch 'errors=[1-9][0-9]*') {
            throw "critical reparse ancestor did not fail closed; exit=$($criticalReparse.ExitCode)`n$($criticalReparse.StdOut)`n$($criticalReparse.StdErr)"
        }
        Remove-FixtureJunction $criticalSetupPath
        Remove-Item -LiteralPath $criticalReparseTarget -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $criticalSetupPath -Force | Out-Null
        Copy-Item -LiteralPath $fixedRootHelper -Destination (Join-Path $criticalSetupPath 'assert_fixed_install_root.ps1') -Force
        New-Item -ItemType Junction -Path $insideLink -Target $insideTarget -Force | Out-Null

        $envVars['STOCK_VERIFY_SKIP_JUNCTIONS'] = '0'
        $envVars['STOCK_VERIFY_EXPECTED_JUNCTIONS'] = '1'
        $insideResult = Invoke-CmdFixture $verifier $envVars $fixture
        if ($insideResult.ExitCode -ne 0 -or $insideResult.StdOut -notmatch 'Junction count is 1') {
            throw "internal junction target did not pass safely; exit=$($insideResult.ExitCode)"
        }
        Remove-FixtureJunction $insideLink
        Remove-Item -LiteralPath $insideTarget -Recurse -Force -ErrorAction SilentlyContinue

        $outsideTarget = Join-Path ([IO.Path]::GetTempPath()) ('stock-verifier-outside-' + [Guid]::NewGuid().ToString('N'))
        $outsideLink = Join-Path $fixture 'scripts\setup\junction-outside'
        New-Item -ItemType Directory -Path $outsideTarget -Force | Out-Null
        New-Item -ItemType Junction -Path $outsideLink -Target $outsideTarget -Force | Out-Null
        $outsideResult = Invoke-CmdFixture $verifier $envVars $fixture
        if ($outsideResult.ExitCode -eq 0 -or $outsideResult.StdOut -notmatch 'reparse targets leave') {
            throw 'external junction target did not fail closed'
        }
        Remove-FixtureJunction $outsideLink
        Remove-Item -LiteralPath $outsideTarget -Recurse -Force -ErrorAction SilentlyContinue

        $gitJunctionTarget = Join-Path ([IO.Path]::GetTempPath()) ('stock-verifier-git-target-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $gitJunctionTarget -Force | Out-Null
        Remove-Item -LiteralPath $gitMetadata -Recurse -Force
        New-Item -ItemType Junction -Path $gitMetadata -Target $gitJunctionTarget -Force | Out-Null
        $gitJunctionResult = Invoke-CmdFixture $verifier $envVars $fixture
        if ($gitJunctionResult.ExitCode -eq 0 -or $gitJunctionResult.StdOut -notmatch 'Git metadata is missing, external, or unsafe') {
            throw 'external .git junction did not fail closed'
        }
        Remove-FixtureJunction $gitMetadata
        New-Item -ItemType Directory -Path $gitMetadata -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $gitMetadata 'config') -Force | Out-Null
        Remove-Item -LiteralPath $gitJunctionTarget -Recurse -Force -ErrorAction SilentlyContinue
        $envVars['STOCK_VERIFY_SKIP_JUNCTIONS'] = '1'
        $envVars['STOCK_VERIFY_EXPECTED_JUNCTIONS'] = '0'
    }
    if ($before -cne (Get-FixtureSnapshot $fixture)) {
        throw 'negative verifier probes did not restore the fixture snapshot'
    }

    $probe = Join-Path $fixture 'probe-requirements.txt'
    Write-Utf8NoBom $probe "pip`r`npython-dateutil`r`nbeautifulsoup4`r`nJinja2`r`n"
    $venvPython = Join-Path $testRoot '.venv\Scripts\python.exe'
    $probeOutput = & $venvPython $helper --requirements $probe 2>&1
    if ($LASTEXITCODE -ne 0 -or ($probeOutput -join "`n") -notmatch 'direct_requirements=4 failures=0') {
        throw "Python helper alias probe failed with exit code $LASTEXITCODE"
    }
    Write-Utf8NoBom $probe "pip`r`ndefinitely-not-installed-for-verifier-test`r`n"
    $negativeOutput = & $venvPython $helper --requirements $probe 2>&1
    if ($LASTEXITCODE -ne 1 -or ($negativeOutput -join "`n") -notmatch 'distribution-not-installed') {
        throw 'Python helper missing-distribution probe did not fail closed with exit code 1'
    }

    Write-Output '[OK] Test-VerifyStockEnvironment: fixture verifier exit 0, manifests 37+3, optional notice, snapshot unchanged.'
    Write-Output '[OK] Test-VerifyStockEnvironment: Python helper alias pass and missing-distribution fail-closed probes passed.'
    exit 0
} finally {
    if (Test-Path -LiteralPath $fixture) {
        Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
    }
}
