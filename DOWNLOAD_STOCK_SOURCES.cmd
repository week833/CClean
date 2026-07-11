@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "TARGET=%~dp0scripts\sources\clone_stock_analysis_repos.cmd"
if not exist "%TARGET%" (
    echo [ERROR] 找不到來源下載程式：%TARGET%
    pause
    exit /b 1
)

set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%TARGET%" %*
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
if "%RC%"=="0" (
    echo 全部分類來源下載 / 更新完成。
) else (
    echo [ERROR] 來源下載 / 更新發生錯誤，錯誤碼：%RC%
)
pause
exit /b %RC%
