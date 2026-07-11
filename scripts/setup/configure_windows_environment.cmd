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

echo [1/3] 設定使用者環境變數...
setx STOCK_HOME "%CANONICAL_ROOT%" >nul
setx STOCK_REPO "%CANONICAL_ROOT%" >nul
setx STOCK_VENV "%CANONICAL_ROOT%\.venv" >nul
setx STOCK_PYTHON "%CANONICAL_ROOT%\.venv\Scripts\python.exe" >nul
setx STOCK_EXTERNAL_REPOS "%CANONICAL_ROOT%\external_repos" >nul
setx PYTHONUTF8 "1" >nul
setx PYTHONIOENCODING "utf-8" >nul

echo [2/3] 將台股工具加入使用者 PATH...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$add=@('%CANONICAL_ROOT%','%CANONICAL_ROOT%\.venv\Scripts','%CANONICAL_ROOT%\scripts','%CANONICAL_ROOT%\scripts\setup','%CANONICAL_ROOT%\scripts\sources','%CANONICAL_ROOT%\scripts\compat');" ^
  "$p=[Environment]::GetEnvironmentVariable('Path','User');" ^
  "$parts=@(); if($p){$parts=$p.Split(';') ^| Where-Object { $_ -and $_.Trim() }};" ^
  "foreach($item in $add){if(-not ($parts ^| Where-Object { $_.TrimEnd('\\') -ieq $item.TrimEnd('\\') })){$parts += $item}};" ^
  "[Environment]::SetEnvironmentVariable('Path',($parts -join ';'),'User')"
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] 使用者 PATH 更新失敗，但目前視窗仍會設定 PATH。
)

rem 讓目前執行中的批次檔立即可使用，不必重開視窗。
set "STOCK_HOME=%CANONICAL_ROOT%"
set "STOCK_REPO=%CANONICAL_ROOT%"
set "STOCK_VENV=%CANONICAL_ROOT%\.venv"
set "STOCK_PYTHON=%CANONICAL_ROOT%\.venv\Scripts\python.exe"
set "STOCK_EXTERNAL_REPOS=%CANONICAL_ROOT%\external_repos"
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
echo 新開啟的 CMD、PowerShell、排程器與其他應用程式將讀取新的使用者環境變數。
if not defined STOCK_TOOLKIT_NO_PAUSE pause
exit /b 0
