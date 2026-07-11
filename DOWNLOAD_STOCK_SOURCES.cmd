@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "TARGET=%~dp0scripts\sources\clone_stock_analysis_repos.cmd"
if not exist "%TARGET%" (
    echo [ERROR] 找不到來源下載程式：%TARGET%
    pause
    exit /b 1
)

call "%TARGET%" %*
exit /b %ERRORLEVEL%
