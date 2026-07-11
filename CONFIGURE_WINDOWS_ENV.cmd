@echo off
chcp 65001 >nul
setlocal EnableExtensions

set "TARGET=D:\stock\scripts\setup\configure_windows_environment.cmd"
if not exist "%TARGET%" (
    echo [ERROR] 找不到：%TARGET%
    echo 請先執行 INSTALL_D_STOCK_ENV.cmd。
    pause
    exit /b 1
)

call "%TARGET%" %*
exit /b %ERRORLEVEL%
