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

call "%TARGET%" %*
exit /b %ERRORLEVEL%
