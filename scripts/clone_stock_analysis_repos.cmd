@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem 舊路徑相容啟動器：保留 scripts\clone_stock_analysis_repos.cmd。
set "TARGET=%~dp0sources\clone_stock_analysis_repos.cmd"

if not exist "%TARGET%" (
    echo [ERROR] 找不到新的來源下載程式：
    echo %TARGET%
    pause
    exit /b 1
)

set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
if "%RC%"=="0" (
    echo 分類來源下載 / 更新完成。
) else (
    echo [ERROR] 分類來源下載 / 更新失敗，錯誤碼：%RC%
)
pause
exit /b %RC%
