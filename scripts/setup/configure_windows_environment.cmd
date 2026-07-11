@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 設定 D:\stock Windows 使用環境

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "CANONICAL_ROOT=D:\stock"
set "VENV_DIR=%REPO_ROOT%\.venv"
set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "LEGACY_ROOT=D:\Downloads\stock"
set "PS_SCRIPT=%TEMP%\configure_d_stock_env_%RANDOM%_%RANDOM%.ps1"

echo ============================================================
echo  設定 Windows 台股工具使用環境
echo ============================================================
echo Repository：%REPO_ROOT%
echo 正式路徑：%CANONICAL_ROOT%
echo.

if not exist "D:\" (
    echo [ERROR] 找不到 D: 磁碟機。
    exit /b 1
)

rem 若程式不在 D:\stock，且 D:\stock 尚不存在，建立正式路徑 junction。
if /I not "%REPO_ROOT%"=="%CANONICAL_ROOT%" (
    if not exist "%CANONICAL_ROOT%" (
        echo [LINK] %CANONICAL_ROOT% ^-^> %REPO_ROOT%
        mklink /J "%CANONICAL_ROOT%" "%REPO_ROOT%" >nul 2>&1
        if !ERRORLEVEL! NEQ 0 (
            echo [ERROR] 無法建立 %CANONICAL_ROOT% 相容連結。
            echo 請以系統管理員身分重新執行。
            exit /b 1
        )
    ) else (
        echo [KEEP] %CANONICAL_ROOT% 已存在，不覆蓋。
    )
)

if not exist "%CANONICAL_ROOT%\requirements.txt" (
    echo [ERROR] %CANONICAL_ROOT% 不是有效的 stock repository。
    exit /b 1
)

rem 舊路徑已刪除時，建立 D:\Downloads\stock 到 D:\stock 的 junction。
if not exist "D:\Downloads" mkdir "D:\Downloads" >nul 2>&1
if not exist "%LEGACY_ROOT%" (
    echo [LINK] %LEGACY_ROOT% ^-^> %CANONICAL_ROOT%
    mklink /J "%LEGACY_ROOT%" "%CANONICAL_ROOT%" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 echo [WARN] 無法建立舊路徑連結，可能需要系統管理員權限。
) else (
    echo [KEEP] 舊路徑已存在：%LEGACY_ROOT%
)

if not exist "%VENV_PYTHON%" (
    echo [ERROR] 尚未建立虛擬環境：%VENV_PYTHON%
    echo 請先執行 INSTALL_D_STOCK_ENV.cmd 或 install_tw_stock_ai_env.cmd。
    exit /b 1
)

echo [1/3] 設定使用者環境變數與 PATH...
> "%PS_SCRIPT%" echo $ErrorActionPreference = 'Stop'
>> "%PS_SCRIPT%" echo $root = 'D:\stock'
>> "%PS_SCRIPT%" echo $vars = @{
>> "%PS_SCRIPT%" echo   'STOCK_HOME' = $root
>> "%PS_SCRIPT%" echo   'STOCK_REPO' = $root
>> "%PS_SCRIPT%" echo   'STOCK_VENV' = "$root\.venv"
>> "%PS_SCRIPT%" echo   'STOCK_PYTHON' = "$root\.venv\Scripts\python.exe"
>> "%PS_SCRIPT%" echo   'STOCK_EXTERNAL_REPOS' = "$root\external_repos"
>> "%PS_SCRIPT%" echo   'PYTHONUTF8' = '1'
>> "%PS_SCRIPT%" echo   'PYTHONIOENCODING' = 'utf-8'
>> "%PS_SCRIPT%" echo }
>> "%PS_SCRIPT%" echo foreach ($name in $vars.Keys) { [Environment]::SetEnvironmentVariable($name, $vars[$name], 'User') }
>> "%PS_SCRIPT%" echo $add = @($root, "$root\.venv\Scripts", "$root\scripts", "$root\scripts\setup", "$root\scripts\sources", "$root\scripts\compat")
>> "%PS_SCRIPT%" echo $existing = [Environment]::GetEnvironmentVariable('Path', 'User')
>> "%PS_SCRIPT%" echo $parts = New-Object 'System.Collections.Generic.List[string]'
>> "%PS_SCRIPT%" echo if ($existing) { foreach ($entry in $existing.Split(';')) { if ($entry -and $entry.Trim()) { $parts.Add($entry.Trim()) } } }
>> "%PS_SCRIPT%" echo foreach ($item in $add) {
>> "%PS_SCRIPT%" echo   $found = $false
>> "%PS_SCRIPT%" echo   foreach ($entry in $parts) { if ($entry.TrimEnd('\') -ieq $item.TrimEnd('\')) { $found = $true; break } }
>> "%PS_SCRIPT%" echo   if (-not $found) { $parts.Add($item) }
>> "%PS_SCRIPT%" echo }
>> "%PS_SCRIPT%" echo [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "PS_RC=%ERRORLEVEL%"
del "%PS_SCRIPT%" >nul 2>&1
if not "%PS_RC%"=="0" (
    echo [ERROR] 使用者環境變數或 PATH 更新失敗。
    exit /b 1
)

echo [2/3] 設定目前批次程序的環境...
set "STOCK_HOME=%CANONICAL_ROOT%"
set "STOCK_REPO=%CANONICAL_ROOT%"
set "STOCK_VENV=%CANONICAL_ROOT%\.venv"
set "STOCK_PYTHON=%CANONICAL_ROOT%\.venv\Scripts\python.exe"
set "STOCK_EXTERNAL_REPOS=%CANONICAL_ROOT%\external_repos"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
set "PATH=%CANONICAL_ROOT%\.venv\Scripts;%CANONICAL_ROOT%;%CANONICAL_ROOT%\scripts;%PATH%"

echo [3/3] 驗證 Windows 應用程式可呼叫環境...
"%VENV_PYTHON%" -c "import sys, pandas, numpy, requests, yfinance; print(sys.executable); print('WINDOWS_ENV_OK')"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 虛擬環境驗證失敗。
    exit /b 1
)

echo.
echo ============================================================
echo  Windows 環境設定完成
echo ============================================================
echo STOCK_HOME=%CANONICAL_ROOT%
echo STOCK_PYTHON=%CANONICAL_ROOT%\.venv\Scripts\python.exe
echo 舊路徑=%LEGACY_ROOT%
echo.
echo 新開啟的 CMD、PowerShell、VS Code、排程器與其他應用程式將讀取新的使用者環境變數。
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 0
