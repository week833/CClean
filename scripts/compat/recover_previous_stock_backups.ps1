[CmdletBinding()]
param(
    [switch]$ListOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Backups = @(Get-ChildItem -LiteralPath 'D:\' -Directory -Filter 'stock_backup_*' -ErrorAction SilentlyContinue | Sort-Object Name)

if ($Backups.Count -eq 0) {
    Write-Host '[INFO] No D:\stock_backup_* folders were found.' -ForegroundColor Yellow
    exit 0
}

Write-Host 'Previous installer backup folders:' -ForegroundColor Cyan
foreach ($backup in $Backups) {
    Write-Host ("  {0}" -f $backup.FullName)
}

if ($ListOnly) {
    exit 0
}

$SharedRoot = 'D:\stock'
if (-not (Test-Path -LiteralPath $SharedRoot)) {
    New-Item -ItemType Directory -Path $SharedRoot -Force | Out-Null
}

$RecoveryRoot = Join-Path $SharedRoot ("Recovered_from_previous_installer_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $RecoveryRoot -Force | Out-Null

$Report = New-Object 'System.Collections.Generic.List[string]'
$Report.Add("Recovery created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$Report.Add("Recovery root: $RecoveryRoot")
$Report.Add('Source backup folders are not deleted or modified.')
$Report.Add('')

foreach ($backup in $Backups) {
    $Destination = Join-Path $RecoveryRoot $backup.Name
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Write-Host ("[COPY] {0} -> {1}" -f $backup.FullName, $Destination) -ForegroundColor Green
    & robocopy.exe $backup.FullName $Destination /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NP /NFL /NDL
    $code = $LASTEXITCODE

    if ($code -gt 7) {
        $Report.Add("FAILED ($code): $($backup.FullName) -> $Destination")
        throw "Robocopy failed with exit code ${code}: $($backup.FullName)"
    }

    $Report.Add("COPIED ($code): $($backup.FullName) -> $Destination")
}

$ReportPath = Join-Path $RecoveryRoot 'RECOVERY_REPORT.txt'
$Report | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host ''
Write-Host '[OK] Recovery copy completed.' -ForegroundColor Green
Write-Host "Recovery folder: $RecoveryRoot"
Write-Host "Report: $ReportPath"
Write-Host 'Original backup folders remain unchanged.'
exit 0
