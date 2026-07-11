@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1

title D:\stock 台股工具完整安裝程式（穩定版）

set "LOCAL_PS1=%~dp0scripts\setup\install_d_stock_env.ps1"
set "ADJACENT_PS1=%~dp0install_d_stock_env.ps1"
set "TEMP_PS1=%TEMP%\install_d_stock_env_%RANDOM%_%RANDOM%.ps1"
set "PS_SCRIPT="
set "PS_ARGS="
set "EXIT_CODE=1"

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 找不到 Windows PowerShell。
    echo 此安裝程式需要 Windows PowerShell 5.1 或更新版本。
    echo.
    pause
    exit /b 1
)

if exist "%LOCAL_PS1%" set "PS_SCRIPT=%LOCAL_PS1%"
if not defined PS_SCRIPT if exist "%ADJACENT_PS1%" set "PS_SCRIPT=%ADJACENT_PS1%"

if not defined PS_SCRIPT (
    echo ============================================================
    echo  正在下載最新穩定版安裝核心...
    echo ============================================================
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/week833/stock/main/scripts/setup/install_d_stock_env.ps1' -OutFile '%TEMP_PS1%'"
    if errorlevel 1 goto :download_error
    set "PS_SCRIPT=%TEMP_PS1%"
)

if /I "%~1"=="/FULL" set "PS_ARGS=-Full"

echo ============================================================
echo  啟動 D:\stock 安裝程式
echo ============================================================
echo 安裝核心：%PS_SCRIPT%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %PS_ARGS%
set "EXIT_CODE=%ERRORLEVEL%"

if exist "%TEMP_PS1%" del /q "%TEMP_PS1%" >nul 2>nul

echo.
if "%EXIT_CODE%"=="0" (
    echo [OK] 安裝程式執行完成。
) else (
    echo [ERROR] 安裝程式執行失敗，錯誤碼：%EXIT_CODE%
    echo 請查看：%TEMP%\install_d_stock_env.log
)
echo.
echo 按任意鍵關閉視窗...
pause >nul
exit /b %EXIT_CODE%

:download_error
echo.
echo [ERROR] 無法下載安裝核心。
echo 請確認網路可連線至 GitHub，或將 install_d_stock_env.ps1 放在本檔案旁邊。
echo.
echo 按任意鍵關閉視窗...
pause >nul
exit /b 1
