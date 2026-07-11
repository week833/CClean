@echo off
chcp 65001 >nul
setlocal EnableExtensions

title 台股工具環境安裝與路徑相容管理器
set "REPO_ROOT=%~dp0"

:menu
cls
echo ============================================================
echo  台股工具環境安裝與路徑相容管理器
echo ============================================================
echo Repository：%REPO_ROOT%
echo.
echo [1] 安裝 / 修復核心 Python 環境
echo [2] 下載 / 更新全部分類來源
echo [3] 下載舊版相容來源
echo [4] 修復舊檔名與舊資料夾路徑
echo [5] 完整執行：環境 + 全部來源 + 相容修復 + 檢查
echo [6] 只檢查目前環境
echo [Q] 離開
echo.
choice /C 123456Q /N /M "請選擇："

if errorlevel 7 goto :end
if errorlevel 6 goto :verify
if errorlevel 5 goto :full
if errorlevel 4 goto :repair
if errorlevel 3 goto :legacy
if errorlevel 2 goto :sources
if errorlevel 1 goto :install

:install
set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%REPO_ROOT%scripts\setup\install_tw_stock_ai_env.cmd"
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
echo 執行結果：%RC%
pause
goto :menu

:sources
set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%REPO_ROOT%scripts\sources\clone_stock_analysis_repos.cmd"
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
echo 執行結果：%RC%
pause
goto :menu

:legacy
set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%REPO_ROOT%scripts\sources\clone_legacy_compat_repos.cmd"
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
echo 執行結果：%RC%
pause
goto :menu

:repair
set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%REPO_ROOT%scripts\compat\repair_legacy_paths.cmd"
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
echo 執行結果：%RC%
pause
goto :menu

:verify
set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%REPO_ROOT%scripts\compat\verify_stock_environment.cmd"
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
echo 執行結果：%RC%
pause
goto :menu

:full
set "STOCK_TOOLKIT_NO_PAUSE=1"
echo.
echo [FULL 1/5] 安裝核心環境...
call "%REPO_ROOT%scripts\setup\install_tw_stock_ai_env.cmd" || goto :full_error

echo.
echo [FULL 2/5] 下載全部分類來源...
call "%REPO_ROOT%scripts\sources\clone_stock_analysis_repos.cmd" || goto :full_error

echo.
echo [FULL 3/5] 下載舊版相容來源...
call "%REPO_ROOT%scripts\sources\clone_legacy_compat_repos.cmd" || goto :full_error

echo.
echo [FULL 4/5] 修復舊路徑...
call "%REPO_ROOT%scripts\compat\repair_legacy_paths.cmd" || goto :full_error

echo.
echo [FULL 5/5] 驗證環境...
call "%REPO_ROOT%scripts\compat\verify_stock_environment.cmd"
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
echo 完整流程完成，檢查結果：%RC%
pause
goto :menu

:full_error
set "RC=%ERRORLEVEL%"
set "STOCK_TOOLKIT_NO_PAUSE="
echo.
echo [ERROR] 完整流程中斷，錯誤碼：%RC%
pause
goto :menu

:end
exit /b 0
