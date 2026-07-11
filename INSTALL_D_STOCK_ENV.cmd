@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title D:\stock 台股工具完整安裝程式

set "INSTALL_ROOT=D:\stock"
set "REPO_URL=https://github.com/week833/stock.git"
set "LOG_FILE=%TEMP%\install_d_stock_env.log"
set "FULL_INSTALL=0"
if /I "%~1"=="/FULL" set "FULL_INSTALL=1"

echo ============================================================
echo  D:\stock 台股工具完整安裝程式
echo ============================================================
echo 正式安裝位置：%INSTALL_ROOT%
echo GitHub：%REPO_URL%
echo 紀錄檔：%LOG_FILE%
echo.

if not exist "D:\" (
    echo [ERROR] 找不到 D: 磁碟機。
    pause
    exit /b 1
)

echo ============================================================ > "%LOG_FILE%"
echo D:\stock installation started: %DATE% %TIME% >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"

echo [1/8] 檢查 Git...
call :find_git
if not defined GIT_EXE (
    where winget >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        echo [INSTALL] 使用 winget 安裝 Git for Windows...
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements >> "%LOG_FILE%" 2>&1
        set "PATH=%ProgramFiles%\Git\cmd;%LOCALAPPDATA%\Programs\Git\cmd;%PATH%"
        call :find_git
    )
)
if not defined GIT_EXE (
    echo [ERROR] 找不到 Git，且無法自動安裝。
    echo 請安裝 Git for Windows 後重新執行。
    pause
    exit /b 1
)
echo [OK] Git：%GIT_EXE%

echo [2/8] 檢查 Python 3...
call :find_python
if not defined PYTHON_EXE (
    where winget >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        echo [INSTALL] 使用 winget 安裝 Python 3.12...
        winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements >> "%LOG_FILE%" 2>&1
        set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%LOCALAPPDATA%\Programs\Python\Launcher;%PATH%"
        call :find_python
    )
)
if not defined PYTHON_EXE (
    echo [ERROR] 找不到 Python 3，且無法自動安裝。
    echo 安裝 Python 時請勾選 Add Python to PATH。
    pause
    exit /b 1
)
for %%I in ("%PYTHON_EXE%") do set "PATH=%%~dpI;%PATH%"
echo [OK] Python：%PYTHON_EXE%
"%PYTHON_EXE%" --version

echo [3/8] 建立或更新 D:\stock repository...
if exist "%INSTALL_ROOT%\.git" (
    echo [UPDATE] 更新既有 repository...
    "%GIT_EXE%" -C "%INSTALL_ROOT%" fetch --prune >> "%LOG_FILE%" 2>&1
    "%GIT_EXE%" -C "%INSTALL_ROOT%" checkout main >> "%LOG_FILE%" 2>&1
    "%GIT_EXE%" -C "%INSTALL_ROOT%" pull --ff-only origin main >> "%LOG_FILE%" 2>&1
    if !ERRORLEVEL! NEQ 0 goto :error
) else (
    if exist "%INSTALL_ROOT%" (
        dir /b "%INSTALL_ROOT%" 2>nul | findstr . >nul
        if !ERRORLEVEL! EQU 0 (
            for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%T"
            set "BACKUP_ROOT=D:\stock_backup_!STAMP!"
            echo [BACKUP] 既有非 Git 資料夾移至 !BACKUP_ROOT!
            move "%INSTALL_ROOT%" "!BACKUP_ROOT!" >> "%LOG_FILE%" 2>&1
            if !ERRORLEVEL! NEQ (
                echo [ERROR] 無法備份既有 D:\stock，請關閉正在使用該資料夾的程式。
                pause
                exit /b 1
            )
        ) else (
            rmdir "%INSTALL_ROOT%" >nul 2>&1
        )
    )
    echo [CLONE] 下載 week833/stock...
    "%GIT_EXE%" clone "%REPO_URL%" "%INSTALL_ROOT%" >> "%LOG_FILE%" 2>&1
    if !ERRORLEVEL! NEQ 0 goto :error
)

echo [4/8] 建立 / 修復 Python 虛擬環境...
set "STOCK_TOOLKIT_NO_PAUSE=1"
call "%INSTALL_ROOT%\scripts\setup\install_tw_stock_ai_env.cmd"
if !ERRORLEVEL! NEQ 0 goto :error_no_pause

echo [5/8] 設定 Windows 使用者環境變數與 PATH...
call "%INSTALL_ROOT%\scripts\setup\configure_windows_environment.cmd"
if !ERRORLEVEL! NEQ 0 goto :error_no_pause

echo [6/8] 建立舊路徑相容連結...
call "%INSTALL_ROOT%\scripts\compat\repair_legacy_paths.cmd"
if !ERRORLEVEL! NEQ 0 goto :error_no_pause

echo [7/8] 驗證環境...
call "%INSTALL_ROOT%\scripts\compat\verify_stock_environment.cmd"
if !ERRORLEVEL! NEQ 0 goto :error_no_pause

if "%FULL_INSTALL%"=="1" (
    echo [8/8] 下載 / 更新全部外部研究來源...
    call "%INSTALL_ROOT%\scripts\sources\clone_stock_analysis_repos.cmd"
    if !ERRORLEVEL! NEQ 0 goto :error_no_pause
) else (
    echo [8/8] 略過大型外部來源下載。
    echo       需要時可執行 DOWNLOAD_STOCK_SOURCES.cmd，或以 /FULL 參數重新執行。
)
set "STOCK_TOOLKIT_NO_PAUSE="

echo.
echo ============================================================
echo  安裝與環境設定完成
echo ============================================================
echo 正式路徑：D:\stock
echo Python：D:\stock\.venv\Scripts\python.exe
echo 舊路徑：D:\Downloads\stock ^-^> D:\stock
echo 使用者環境變數：STOCK_HOME、STOCK_PYTHON、STOCK_VENV
echo.
echo 請關閉後重新開啟 CMD、PowerShell、VS Code、排程器或其他應用程式，讓新 PATH 生效。
echo 可雙擊 OPEN_STOCK_TERMINAL.cmd 直接進入已啟用環境。
echo.
pause
exit /b 0

:find_git
set "GIT_EXE="
for /f "delims=" %%G in ('where git 2^>nul') do if not defined GIT_EXE set "GIT_EXE=%%G"
if not defined GIT_EXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_EXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GIT_EXE if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "GIT_EXE=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"
exit /b 0

:find_python
set "PYTHON_EXE="
for /f "delims=" %%P in ('py -3 -c "import sys;print(sys.executable)" 2^>nul') do if not defined PYTHON_EXE set "PYTHON_EXE=%%P"
if not defined PYTHON_EXE for /f "delims=" %%P in ('python -c "import sys;print(sys.executable)" 2^>nul') do if not defined PYTHON_EXE set "PYTHON_EXE=%%P"
if not defined PYTHON_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
exit /b 0

:error_no_pause
set "STOCK_TOOLKIT_NO_PAUSE="
:error
echo.
echo [ERROR] 安裝流程失敗。
echo 請查看紀錄：%LOG_FILE%
pause
exit /b 1
