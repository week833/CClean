# 台股 AI 分析與量化研究工具庫

本 repository 的 Windows 正式安裝位置為：

```text
D:\stock
```

已加入自動安裝、Windows 使用者環境變數、PATH、舊路徑相容與環境驗證機制。即使原本的 `D:\Downloads\stock` 已刪除，也能重新建立可供 CMD、PowerShell、VS Code、排程器與其他應用程式使用的環境。

## 新電腦或舊資料已刪除：直接執行

下載根目錄的：

```cmd
INSTALL_D_STOCK_ENV.cmd
```

然後按右鍵選擇「以系統管理員身分執行」。程式會自動：

1. 檢查 Git 與 Python；缺少時嘗試透過 `winget` 安裝。
2. 將 `week833/stock` clone 或更新到 `D:\stock`。
3. 建立或沿用 `D:\stock\.venv`。
4. 安裝 `requirements.txt` 中的套件。
5. 設定使用者環境變數與 PATH。
6. 建立 `D:\Downloads\stock -> D:\stock` 相容連結。
7. 驗證核心套件與應用程式使用環境。

預設不下載大型外部研究 repository。需要全部下載時可執行：

```cmd
INSTALL_D_STOCK_ENV.cmd /FULL
```

## Windows 應用程式可使用的設定

安裝完成後會建立以下使用者環境變數：

```text
STOCK_HOME=D:\stock
STOCK_REPO=D:\stock
STOCK_VENV=D:\stock\.venv
STOCK_PYTHON=D:\stock\.venv\Scripts\python.exe
STOCK_EXTERNAL_REPOS=D:\stock\external_repos
PYTHONUTF8=1
PYTHONIOENCODING=utf-8
```

並將下列路徑加入使用者 PATH：

```text
D:\stock
D:\stock\.venv\Scripts
D:\stock\scripts
D:\stock\scripts\setup
D:\stock\scripts\sources
D:\stock\scripts\compat
```

設定完成後，請關閉再重新開啟 CMD、PowerShell、VS Code、排程器或其他應用程式，讓新的使用者環境生效。

## 根目錄可雙擊執行檔

| 執行檔 | 用途 |
|---|---|
| [`INSTALL_D_STOCK_ENV.cmd`](./INSTALL_D_STOCK_ENV.cmd) | 從零建立 `D:\stock`、Python 環境、PATH 與相容路徑 |
| [`STOCK_SETUP_MANAGER.cmd`](./STOCK_SETUP_MANAGER.cmd) | 統一安裝、下載、修復與檢查選單 |
| [`CONFIGURE_WINDOWS_ENV.cmd`](./CONFIGURE_WINDOWS_ENV.cmd) | 重新設定 Windows 使用者環境變數與 PATH |
| [`OPEN_STOCK_TERMINAL.cmd`](./OPEN_STOCK_TERMINAL.cmd) | 開啟位於 `D:\stock` 且已啟用 `.venv` 的 CMD |
| [`RUN_STOCK_PYTHON.cmd`](./RUN_STOCK_PYTHON.cmd) | 直接使用 `D:\stock\.venv\Scripts\python.exe` 執行程式 |
| [`install_tw_stock_ai_env.cmd`](./install_tw_stock_ai_env.cmd) | 保留舊檔名的核心環境安裝入口 |
| [`DOWNLOAD_STOCK_SOURCES.cmd`](./DOWNLOAD_STOCK_SOURCES.cmd) | 下載 / 更新全部分類來源 |
| [`DOWNLOAD_LEGACY_SOURCES.cmd`](./DOWNLOAD_LEGACY_SOURCES.cmd) | 下載舊版安裝程式曾使用的額外來源 |
| [`REPAIR_STOCK_PATHS.cmd`](./REPAIR_STOCK_PATHS.cmd) | 修復舊資料夾與固定路徑相容性 |
| [`VERIFY_STOCK_ENV.cmd`](./VERIFY_STOCK_ENV.cmd) | 檢查 `D:\stock`、環境變數、PATH、`.venv` 與套件匯入 |

## 最簡單的後續管理方式

直接雙擊：

```cmd
STOCK_SETUP_MANAGER.cmd
```

可選擇：

1. 安裝 / 修復核心 Python 環境
2. 下載 / 更新全部分類來源
3. 下載舊版相容來源
4. 修復舊檔名與舊資料夾路徑
5. 完整建置全部環境
6. 檢查目前環境

## 舊路徑相容

正式路徑已改為：

```text
D:\stock
```

原本的：

```text
D:\Downloads\stock
```

若不存在，安裝或修復程式會建立 Windows junction：

```text
D:\Downloads\stock -> D:\stock
```

因此仍寫死舊路徑的既有程式可繼續運作。若 junction 建立失敗，請以系統管理員身分執行 `INSTALL_D_STOCK_ENV.cmd` 或 `REPAIR_STOCK_PATHS.cmd`。

## 保留的舊檔案路徑

以下入口仍可使用：

```text
install_tw_stock_ai_env.cmd
scripts\clone_stock_analysis_repos.cmd
requirements_tw_stock_ai.txt
external_stock_repositories.md
```

它們會自動轉交到新的分類位置。

## Repository 結構

| 內容 | 路徑 |
|---|---|
| 核心 Python 套件 | [`requirements.txt`](./requirements.txt) |
| Windows 核心環境安裝 | [`scripts/setup/install_tw_stock_ai_env.cmd`](./scripts/setup/install_tw_stock_ai_env.cmd) |
| Windows 環境變數設定 | [`scripts/setup/configure_windows_environment.cmd`](./scripts/setup/configure_windows_environment.cmd) |
| 外部來源下載 / 更新 | [`scripts/sources/clone_stock_analysis_repos.cmd`](./scripts/sources/clone_stock_analysis_repos.cmd) |
| 舊路徑修復 | [`scripts/compat/repair_legacy_paths.cmd`](./scripts/compat/repair_legacy_paths.cmd) |
| 環境檢查 | [`scripts/compat/verify_stock_environment.cmd`](./scripts/compat/verify_stock_environment.cmd) |
| 完整來源清單 | [`docs/external_stock_repositories.md`](./docs/external_stock_repositories.md) |
| 相容性說明 | [`docs/legacy_compatibility.md`](./docs/legacy_compatibility.md) |
| Repository 結構 | [`docs/repository_structure.md`](./docs/repository_structure.md) |
| 依來源分類的資料夾 | [`sources/`](./sources/) |

## 外部來源分類

目前共整理 36 個股票分析相關 GitHub 來源：

1. [`01_taiwan_stock_data`](./sources/01_taiwan_stock_data/)：台股資料與既有分析工具
2. [`02_market_data_platforms`](./sources/02_market_data_platforms/)：金融資料與市場研究平台
3. [`03_ai_ml_forecasting`](./sources/03_ai_ml_forecasting/)：AI、ML 與時間序列預測
4. [`04_backtesting_engines`](./sources/04_backtesting_engines/)：回測與策略測試
5. [`05_indicators_factors_portfolio`](./sources/05_indicators_factors_portfolio/)：指標、因子、績效與投組風控

實際原始碼下載到：

```text
D:\stock\external_repos\<分類>\<來源>\
```

第三方原始碼由 `.gitignore` 排除，不會誤提交回本 repository。

## 其他應用程式設定範例

需要指定 Python 解譯器時，使用：

```text
D:\stock\.venv\Scripts\python.exe
```

需要指定工作目錄時，使用：

```text
D:\stock
```

排程器、IDE 或其他程式也可讀取：

```text
%STOCK_HOME%
%STOCK_PYTHON%
%STOCK_EXTERNAL_REPOS%
```

## 安全提醒

不要提交：

- `.env`、API Token、金鑰
- `.venv/`
- log、cache、產出報告
- `external_repos/` 與 `github_sources/` 內的第三方原始碼

大型框架建議使用各自的獨立虛擬環境，以避免版本衝突。
