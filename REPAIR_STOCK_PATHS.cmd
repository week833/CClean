@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "TARGET=%~dp0scripts\compat\repair_legacy_paths.cmd"
if not exist "%TARGET%" (
    echo [ERROR] 找不到路徑修復程式：%TARGET%
    pause
    exit /b 1
)

call "%TARGET%" %*
exit /b %ERRORLEVEL%
