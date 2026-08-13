# 台股 AI 分析與量化研究工具庫

Windows 安全安裝位置固定為：

```text
D:\stock\GitHub
```

完整安裝契約與 CI/本機驗證邊界見
[`docs/windows_installer_package.md`](docs/windows_installer_package.md)。

`D:\stock` 現在只視為共用資料夾。安裝器不會搬移、刪除、重新命名或覆蓋直接放在 `D:\stock` 內的其他程式。

## 第一次使用：下載完整安裝包

第一次使用時，請從 GitHub 下載本 repository 的完整內容（ZIP 完整解壓，或用
Git clone），再從解壓後的 package 目錄雙擊 `INSTALL_D_STOCK_ENV_FULL.cmd`。
不能只把單一 CMD 檔另存到桌面：安裝器需要同一套 `scripts/`、`requirements.txt`
與 manifest，並且不會從 GitHub 自動下載缺少的 PowerShell 核心。package 可以從
任何暫存資料夾啟動；核心成功寫入並驗證 `D:\stock\GitHub` 後，所有來源下載、修復、
環境重設、驗證與終端機操作都只會使用該固定 root。

若固定 root 已存在但不是預期 repository、origin 不符、包含不受管理的錯誤非空內容，
或 root、`.git`、`.venv`、scripts、repos、來源目標及其祖先是 reparse point，流程會
fail-closed 停止；不會搬移、刪除或覆蓋 `D:\stock` 的其他項目。

## 安裝器入口與操作模式

一般使用者可直接雙擊選單：

```cmd
STOCK_SETUP_MANAGER.cmd
```

選單提供八項獨立操作：

1. Preflight / dry-run：只讀盤點，預設不下載、不安裝、不寫入。
2. Complete installation：核心環境安裝後預設下載 3 個 core primary 與 2 個 unique legacy compatibility 來源，最後唯讀驗證。
3. Download primary research sources：預設 3 個 core；使用 `--all` 才下載全部 37 個 primary。
4. Download legacy sources：下載 2 個 unique legacy，並檢查共享的 `twstock` alias。
5. Repair legacy paths：先執行 `--check`；check 成功後顯示 Y/N 提示，只有明確選 Y 才執行 `--apply --confirm` 建立允許的 junction，選 N 直接返回選單。
6. Reconfigure user environment and PATH：使用既有選項 6 正式設定；`/PREFLIGHT` 為唯讀預覽。
7. Verify installed environment：唯讀驗證固定 root、Git、Python、`.venv`、PATH、來源與 junction。
8. Open terminal with the managed venv enabled：開啟 `D:\stock\GitHub\.venv`。

也可以直接雙擊以下 wrapper：

```cmd
INSTALL_D_STOCK_ENV.cmd /PREFLIGHT
INSTALL_D_STOCK_ENV_FULL.cmd /PREFLIGHT
CONFIGURE_WINDOWS_ENV.cmd /PREFLIGHT
DOWNLOAD_STOCK_SOURCES.cmd --check
DOWNLOAD_LEGACY_SOURCES.cmd --check
REPAIR_STOCK_PATHS.cmd --check
VERIFY_STOCK_ENV.cmd
OPEN_STOCK_TERMINAL.cmd
```

正式安裝會檢查 Git、Windows Python launcher/`winget`，Python 以 3.10–3.12 為支援範圍並優先 3.12；缺少工具時才提出固定套件 ID 的安裝計畫。Windows 可能另外顯示 UAC 提示。
安裝器會建立或沿用 `D:\stock\GitHub\.venv`，並在該環境安裝 `requirements.txt` 的 28 個 direct requirements。
完整安裝不會自動建立 legacy junction；如需修復，請回到選單選項 5，完成 check 後再明確選 Y。完整安裝的來源階段固定先處理 3 個 core primary、2 個 unique legacy，再進行唯讀驗證；全部 37 個 primary 需由選單選項 3 的 `--all` 明確選擇。

外部來源存放於：

```text
D:\stock\GitHub\repos
```

## 安全原則

新版安裝器：

- 不會搬移整個 `D:\stock`。
- 不會刪除 `D:\stock` 內其他程式。
- 不會覆蓋非本 repository 的 `D:\stock\GitHub`。
- 若 `D:\stock\GitHub` 已存在且不是正確 repository，會安全停止並顯示錯誤。
- 若 repository origin 不正確，或固定 root 內有未被安裝器管理的既有非空內容，會 fail closed 停止並提示，不會搬移、刪除或覆寫。
- 若 `.venv` 不完整，會安全停止，不會自行刪除或重建該資料夾。
- 不會在安裝或驗證流程自動建立 legacy junction；請先 `REPAIR_STOCK_PATHS.cmd --check`，再明確執行 `--apply --confirm`。
- `--check`、`--dry-run`、`/PREFLIGHT` 只讀，不會 clone、pull、安裝套件、寫 User env 或建立 junction。

## 復原前版安裝器搬走的程式

舊版安裝器可能曾把整個 `D:\stock` 移至：

```text
D:\stock_backup_YYYYMMDD_HHMMSS
```

可執行：

```cmd
RECOVER_MOVED_STOCK_PROGRAMS.cmd
```

復原工具目前僅列出並檢查舊 `D:\stock_backup_*` 來源；依專案不再建立額外備份的政策，不會複製成第二份 recovery 目錄，也不會覆蓋目前的 `D:\stock` 程式。

## Windows 應用程式設定

完成後會設定：

```text
STOCK_HOME=D:\stock\GitHub
STOCK_REPO=D:\stock\GitHub
STOCK_SHARED_ROOT=D:\stock
STOCK_VENV=D:\stock\GitHub\.venv
STOCK_PYTHON=D:\stock\GitHub\.venv\Scripts\python.exe
STOCK_EXTERNAL_REPOS=D:\stock\GitHub\repos
```

User PATH 會以完整固定路徑管理以下六項（不是以目前工作目錄推算）：

```text
D:\stock\GitHub
D:\stock\GitHub\.venv\Scripts
D:\stock\GitHub\scripts
D:\stock\GitHub\scripts\setup
D:\stock\GitHub\scripts\sources
D:\stock\GitHub\scripts\compat
```

需要指定 Python 解譯器時使用：

```text
D:\stock\GitHub\.venv\Scripts\python.exe
```

安裝完成後請重新開啟 CMD、PowerShell、VS Code、排程器或其他應用程式。

`VERIFY_STOCK_ENV.cmd` 只做唯讀環境驗證：固定 root/reparse 安全、Git 與
normalized exact origin、dirty 狀態、venv Python/pip、`pip check`、28 個 direct
requirement 的 distribution/import alias、上述六項 PATH、37 primary 與 3 legacy
source identities，以及既有 junction 參考。AI／Agent 八個研究來源是 optional，
不列入 formal gate。Verifier 不會執行正式全市場分析，也不證明任何第三方策略的
績效、盈利能力或資料品質。

## 可雙擊執行檔

| 執行檔 | 用途 |
|---|---|
| `INSTALL_D_STOCK_ENV_FULL.cmd` | 核心環境、3 個 core primary、2 個 unique legacy 與唯讀驗證的完整流程；`/PREFLIGHT` 只預覽；全部 37 個 primary 由選單 `--all` opt-in |
| `INSTALL_D_STOCK_ENV.cmd` | 核心安裝；`/PREFLIGHT`、`/DRY-RUN` 只預覽，`/CHECK` 只檢查 PowerShell |
| `RECOVER_MOVED_STOCK_PROGRAMS.cmd` | 唯讀列出並檢查前版搬走的舊備份 |
| `STOCK_SETUP_MANAGER.cmd` | 八項安裝、下載、修復與檢查選單 |
| `CONFIGURE_WINDOWS_ENV.cmd` | 重新設定環境變數與 PATH |
| `OPEN_STOCK_TERMINAL.cmd` | 開啟已啟用虛擬環境的 CMD |
| `RUN_STOCK_PYTHON.cmd` | 使用固定 Python 執行程式 |
| `DOWNLOAD_STOCK_SOURCES.cmd` | 預設下載 3 個 core；`--all` 才下載全部 37 個 primary |
| `DOWNLOAD_LEGACY_SOURCES.cmd` | 下載 2 個 unique legacy，並檢查共享 alias |
| `REPAIR_STOCK_PATHS.cmd` | `--check` 只讀檢查；`--apply --confirm` 才建立允許的 junction |
| `VERIFY_STOCK_ENV.cmd` | 唯讀驗證固定 root、Git/origin、Python、`.venv`、37 來源、legacy 與 junction |

## 來源分類

目前整理 37 個 primary 股票分析 GitHub 來源，另管理 3 個 legacy compatibility
identities，並收錄 8 個 AI／Agent 開發研究來源（optional）：

```text
sources/
├─ taiwan_market_data/
├─ global_market_data/
├─ machine_learning_forecasting/
├─ backtesting_engines/
├─ quant_portfolio_risk/
└─ ai_agent_tools/
```

第三方原始碼位於 `repos/`，並由 `.gitignore` 排除。

`repos/ai_agent_tools/` 只供 AI、Agent 與開發方法研究；正式台股分析不直接匯入這些 repository 的推薦名單、模型或執行結果。

## 錯誤紀錄

```text
%TEMP%\install_d_stock_env.log
```
