@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem 舊路徑相容啟動器：保留原本根目錄檔名，轉交新的分類路徑。
set "REPO_ROOT=%~dp0"
set "TARGET=%REPO_ROOT%scripts\setup\install_tw_stock_ai_env.cmd"

if not exist "%TARGET%" (
    echo [ERROR] 找不到新的環境安裝程式：
    echo %TARGET%
    pause
    exit /b 1
)

call "%TARGET%" %*
exit /b %ERRORLEVEL%
