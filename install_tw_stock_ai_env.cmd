@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

title 台股AI分析環境自動安裝程式

echo ============================================================
echo  台股AI分析環境自動安裝程式
echo ============================================================
echo.
echo  這個程式會自動執行：
echo   1. 建立 D:\Downloads\stock 資料夾
echo   2. 建立 Python 虛擬環境 .venv
echo   3. 安裝台股分析常用套件
echo   4. 測試 FinMind / twstock / yfinance 等套件
echo   5. 若電腦有 git，會自動 clone 參考 GitHub 專案
echo.
echo  安裝紀錄會寫入 install_tw_stock_ai_env.log
echo ============================================================
echo.

set "PROJECT_DIR=D:\Downloads\stock"
set "LOG_FILE=%PROJECT_DIR%\install_tw_stock_ai_env.log"

if not exist "%PROJECT_DIR%" (
    echo [INFO] 建立資料夾：%PROJECT_DIR%
    mkdir "%PROJECT_DIR%"
)

cd /d "%PROJECT_DIR%" || (
    echo [ERROR] 無法進入 %PROJECT_DIR%
    pause
    exit /b 1
)

echo ============================================================ > "%LOG_FILE%"
echo 台股AI分析環境自動安裝開始：%DATE% %TIME% >> "%LOG_FILE%"
echo ============================================================ >> "%LOG_FILE%"

echo.
echo [1/8] 檢查 Python...
where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set "PY_CMD=py -3"
) else (
    where python >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        set "PY_CMD=python"
    ) else (
        echo [ERROR] 找不到 Python。請先安裝 Python 3.10 以上版本。
        echo [ERROR] 找不到 Python。請先安裝 Python 3.10 以上版本。 >> "%LOG_FILE%"
        echo.
        echo 建議安裝網址：https://www.python.org/downloads/windows/
        pause
        exit /b 1
    )
)

%PY_CMD% --version
%PY_CMD% --version >> "%LOG_FILE%" 2>&1

echo.
echo [2/8] 建立 Python 虛擬環境 .venv...
if not exist ".venv\Scripts\python.exe" (
    %PY_CMD% -m venv .venv >> "%LOG_FILE%" 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] 建立虛擬環境失敗，請檢查 Python 安裝是否正常。
        echo [ERROR] 建立虛擬環境失敗。 >> "%LOG_FILE%"
        pause
        exit /b 1
    )
) else (
    echo [INFO] 已存在 .venv，略過建立。
    echo [INFO] 已存在 .venv，略過建立。 >> "%LOG_FILE%"
)

echo.
echo [3/8] 啟用虛擬環境...
call ".venv\Scripts\activate.bat"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 啟用虛擬環境失敗。
    echo [ERROR] 啟用虛擬環境失敗。 >> "%LOG_FILE%"
    pause
    exit /b 1
)

echo.
echo [4/8] 更新 pip / setuptools / wheel...
python -m pip install --upgrade pip setuptools wheel >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] pip 更新可能失敗，但仍會繼續安裝套件。
    echo [WARN] pip 更新可能失敗。 >> "%LOG_FILE%"
)

echo.
echo [5/8] 安裝台股分析核心套件...
echo  這一步可能需要數分鐘，請勿關閉視窗。
echo.

python -m pip install ^
    FinMind ^
    twstock ^
    requests ^
    pandas ^
    numpy ^
    yfinance ^
    feedparser ^
    anthropic ^
    beautifulsoup4 ^
    lxml ^
    html5lib ^
    python-dotenv ^
    matplotlib ^
    exchange_calendars ^
    ta ^
    pydantic ^
    pyecharts ^
    loguru ^
    aiohttp ^
    tqdm ^
    pyarrow ^
    openpyxl ^
    xlsxwriter ^
    Jinja2 ^
    reportlab ^
    python-dateutil ^
    pytz ^
    tzdata ^
    --upgrade >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] 有套件安裝失敗。請查看：
    echo        %LOG_FILE%
    echo.
    echo 常見原因：
    echo   1. 網路不穩
    echo   2. Python 版本過舊
    echo   3. 公司網路或防火牆擋住 pip
    echo.
    pause
    exit /b 1
)

echo.
echo [6/8] 產生 requirements_tw_stock_ai.txt...
(
echo FinMind
echo twstock
echo requests
echo pandas
echo numpy
echo yfinance
echo feedparser
echo anthropic
echo beautifulsoup4
echo lxml
echo html5lib
echo python-dotenv
echo matplotlib
echo exchange_calendars
echo ta
echo pydantic
echo pyecharts
echo loguru
echo aiohttp
echo tqdm
echo pyarrow
echo openpyxl
echo xlsxwriter
echo Jinja2
echo reportlab
echo python-dateutil
echo pytz
echo tzdata
) > requirements_tw_stock_ai.txt

echo.
echo [7/8] 測試主要套件是否可正常匯入...

set "TEST_PY=%PROJECT_DIR%\test_imports_tw_stock_ai.py"
if exist "%TEST_PY%" del "%TEST_PY%"

echo import importlib> "%TEST_PY%"
echo modules = [>> "%TEST_PY%"
echo     "FinMind", "twstock", "requests", "pandas", "numpy", "yfinance",>> "%TEST_PY%"
echo     "feedparser", "bs4", "lxml", "html5lib", "dotenv", "matplotlib",>> "%TEST_PY%"
echo     "exchange_calendars", "ta", "pydantic", "pyecharts", "loguru",>> "%TEST_PY%"
echo     "aiohttp", "tqdm", "pyarrow", "openpyxl", "xlsxwriter", "jinja2", "reportlab",>> "%TEST_PY%"
echo ]>> "%TEST_PY%"
echo failed = []>> "%TEST_PY%"
echo for m in modules:>> "%TEST_PY%"
echo     try:>> "%TEST_PY%"
echo         importlib.import_module(m)>> "%TEST_PY%"
echo         print("[OK]", m)>> "%TEST_PY%"
echo     except Exception as e:>> "%TEST_PY%"
echo         print("[FAIL]", m, ":", e)>> "%TEST_PY%"
echo         failed.append(m)>> "%TEST_PY%"
echo if failed:>> "%TEST_PY%"
echo     print("")>> "%TEST_PY%"
echo     print("FAILED MODULES:", ", ".join(failed))>> "%TEST_PY%"
echo     raise SystemExit(1)>> "%TEST_PY%"
echo print("")>> "%TEST_PY%"
echo print("ALL MAIN PACKAGES IMPORTED SUCCESSFULLY")>> "%TEST_PY%"

python "%TEST_PY%" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] 套件測試失敗。請查看：
    echo        %LOG_FILE%
    echo.
    type "%LOG_FILE%"
    pause
    exit /b 1
)

echo [INFO] 套件測試通過。
echo [INFO] 套件測試通過。 >> "%LOG_FILE%"

echo.
echo [8/8] 檢查 git 並下載 GitHub 參考專案...
where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] 找不到 git，略過 GitHub 專案下載。
    echo [WARN] 找不到 git，略過 GitHub 專案下載。 >> "%LOG_FILE%"
    echo.
    echo 若之後想下載 GitHub 專案，可安裝 Git for Windows：
    echo https://git-scm.com/download/win
) else (
    if not exist "github_sources" mkdir "github_sources"
    cd /d "%PROJECT_DIR%\github_sources"

    if not exist "twstock" (
        echo [INFO] clone mlouielu/twstock...
        git clone https://github.com/mlouielu/twstock.git >> "%LOG_FILE%" 2>&1
    ) else (
        echo [INFO] twstock 已存在，略過 clone。
    )

    if not exist "tw_stocker" (
        echo [INFO] clone voidful/tw_stocker...
        git clone https://github.com/voidful/tw_stocker.git >> "%LOG_FILE%" 2>&1
    ) else (
        echo [INFO] tw_stocker 已存在，略過 clone。
    )

    if not exist "python-stock-radar-" (
        echo [INFO] clone william911530-cmyk/python-stock-radar-...
        git clone https://github.com/william911530-cmyk/python-stock-radar-.git >> "%LOG_FILE%" 2>&1
    ) else (
        echo [INFO] python-stock-radar- 已存在，略過 clone。
    )

    if not exist "TW-stock" (
        echo [INFO] clone k66inthesky/TW-stock...
        git clone https://github.com/k66inthesky/TW-stock.git >> "%LOG_FILE%" 2>&1
    ) else (
        echo [INFO] TW-stock 已存在，略過 clone。
    )

    cd /d "%PROJECT_DIR%"
)

echo.
echo ============================================================
echo  安裝完成
echo ============================================================
echo.
echo  專案資料夾：
echo    %PROJECT_DIR%
echo.
echo  虛擬環境：
echo    %PROJECT_DIR%\.venv
echo.
echo  套件清單：
echo    %PROJECT_DIR%\requirements_tw_stock_ai.txt
echo.
echo  安裝紀錄：
echo    %LOG_FILE%
echo.
echo  之後執行你的台股程式前，可先輸入：
echo    cd /d %PROJECT_DIR%
echo    .venv\Scripts\activate
echo.
echo ============================================================

echo 安裝完成：%DATE% %TIME% >> "%LOG_FILE%"

pause
exit /b 0
