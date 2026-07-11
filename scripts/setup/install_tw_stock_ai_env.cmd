@echo off
chcp 65001 >nul
setlocal EnableExtensions

title 台股 AI 核心環境安裝程式

set "REPO_ROOT=%~dp0..\.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"
set "VENV_DIR=%REPO_ROOT%\.venv"
set "LOG_FILE=%REPO_ROOT%\install_tw_stock_ai_env.log"

echo ============================================================
echo  台股 AI 核心環境安裝程式
echo ============================================================
echo Repository：%REPO_ROOT%
echo.

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set "PY_CMD=py -3"
) else (
    where python >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        set "PY_CMD=python"
    ) else (
        echo [ERROR] 找不到 Python，請先安裝 Python 3.10 以上版本。
        pause
        exit /b 1
    )
)

cd /d "%REPO_ROOT%" || exit /b 1

echo [1/5] 建立虛擬環境...
if not exist "%VENV_DIR%\Scripts\python.exe" (
    %PY_CMD% -m venv "%VENV_DIR%" >> "%LOG_FILE%" 2>&1
    if %ERRORLEVEL% NEQ 0 goto :error
)

echo [2/5] 啟用虛擬環境...
call "%VENV_DIR%\Scripts\activate.bat" || goto :error

echo [3/5] 更新安裝工具...
python -m pip install --upgrade pip setuptools wheel >> "%LOG_FILE%" 2>&1

echo [4/5] 安裝 requirements.txt...
python -m pip install -r "%REPO_ROOT%\requirements.txt" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo [5/5] 測試核心套件...
python -c "import FinMind, twstock, pandas, numpy, yfinance, requests, matplotlib, openpyxl; print('核心套件測試成功')" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 goto :error

echo.
echo 安裝完成。
echo 虛擬環境：%VENV_DIR%
echo 紀錄檔：%LOG_FILE%
echo.
echo 若要下載外部來源，執行：
echo scripts\sources\clone_stock_analysis_repos.cmd
pause
exit /b 0

:error
echo.
echo [ERROR] 安裝失敗，請查看：
echo %LOG_FILE%
pause
exit /b 1
