@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1

title D:\stock 台股工具完整下載安裝程式

set "INSTALL_ROOT=D:\stock"
set "LOG_FILE=%TEMP%\install_d_stock_env.log"
set "TEMP_PS1=%TEMP%\install_d_stock_env_full_%RANDOM%_%RANDOM%.ps1"
set "LOCAL_PS1=%INSTALL_ROOT%\scripts\setup\install_d_stock_env.ps1"
set "ADJACENT_PS1=%~dp0install_d_stock_env.ps1"
set "PS_SCRIPT="
set "EXIT_CODE=1"

rem 自動取得系統管理員權限
net session >nul 2>&1
if errorlevel 1 (
    echo ============================================================
    echo  需要系統管理員權限，正在開啟 UAC 視窗...
    echo ============================================================
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '/ELEVATED' -Verb RunAs"
    if errorlevel 1 (
        echo.
        echo [ERROR] 無法取得系統管理員權限。
        echo 請對本檔案按右鍵，選擇「以系統管理員身分執行」。
        echo.
        pause
    )
    exit /b
)

echo ============================================================
echo  D:\stock 台股工具完整下載安裝程式
echo ============================================================
echo.
echo 本程式會完整執行：
echo   1. 檢查或安裝 Git
echo   2. 檢查或安裝 Python 3.10 - 3.12
echo   3. 建立或更新 D:\stock
echo   4. 建立 D:\stock\.venv
echo   5. 安裝 requirements.txt
echo   6. 設定 Windows PATH 與 STOCK_* 環境變數
echo   7. 建立 D:\Downloads\stock 舊路徑相容連結
echo   8. 下載全部分類、大型研究來源與早期相容來源
echo.
echo 正式安裝位置：%INSTALL_ROOT%
echo 錯誤紀錄：%LOG_FILE%
echo.
echo 注意：完整來源可能占用數 GB 以上空間，下載時間取決於網路速度。
echo.

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
    echo [DOWNLOAD] 正在下載最新穩定版安裝核心...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/week833/stock/main/scripts/setup/install_d_stock_env.ps1' -OutFile '%TEMP_PS1%'"
    if errorlevel 1 goto :download_error
    set "PS_SCRIPT=%TEMP_PS1%"
)

echo.
echo [START] 啟動完整安裝...
echo 安裝核心：%PS_SCRIPT%
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Full
set "EXIT_CODE=%ERRORLEVEL%"

if "%EXIT_CODE%"=="0" (
    if exist "D:\stock\scripts\sources\clone_legacy_compat_repos.cmd" (
        echo.
        echo [EXTRA] 下載早期相容來源...
        set "STOCK_TOOLKIT_NO_PAUSE=1"
        call "D:\stock\scripts\sources\clone_legacy_compat_repos.cmd"
        if errorlevel 1 set "EXIT_CODE=1"
        set "STOCK_TOOLKIT_NO_PAUSE="
    )
)

if exist "%TEMP_PS1%" del /q "%TEMP_PS1%" >nul 2>&1

echo.
echo ============================================================
if "%EXIT_CODE%"=="0" (
    echo  [OK] 完整安裝與全部來源下載完成
    echo ============================================================
    echo.
    echo 正式路徑：D:\stock
    echo Python：D:\stock\.venv\Scripts\python.exe
    echo 外部來源：D:\stock\external_repos
    echo 舊路徑：D:\Downloads\stock
    echo.
    echo 請關閉後重新開啟 CMD、PowerShell、VS Code 或其他應用程式，
    echo 讓新的 PATH 與環境變數生效。
) else (
    echo  [ERROR] 完整安裝失敗，錯誤碼：%EXIT_CODE%
    echo ============================================================
    echo.
    echo 請查看紀錄：
    echo %LOG_FILE%
)
echo.
echo 按任意鍵關閉視窗...
pause >nul
exit /b %EXIT_CODE%

:download_error
echo.
echo ============================================================
echo  [ERROR] 無法下載 PowerShell 安裝核心
echo ============================================================
echo.
echo 請確認：
echo   1. 電腦可以連線 GitHub
echo   2. 防火牆或公司網路沒有封鎖 raw.githubusercontent.com
echo   3. Windows PowerShell 可以使用 TLS 1.2
echo.
echo 也可以將 install_d_stock_env.ps1 放在本檔案旁邊後重新執行。
echo.
echo 按任意鍵關閉視窗...
pause >nul
exit /b 1
