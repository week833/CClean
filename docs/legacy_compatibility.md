# D:\stock\GitHub 與舊路徑相容說明

正式安裝 root 固定為：

```text
D:\stock\GitHub
```

`D:\stock` 是共用資料夾，安裝器不會搬移、刪除、改名或覆蓋其中其他內容。
目標 root 若不是預期的 Git repository、origin 不符、含錯誤的非空內容，或 root、
`.git`、`.venv`、scripts、repos/來源 target（含祖先）是 reparse point，流程會
fail-closed 並保留現況。package 可從其他資料夾啟動，但核心成功後 operational
actions 只使用已驗證的 `D:\stock\GitHub`。

## 建議流程

第一次使用請先取得並完整解壓 GitHub repository/package，不能只下載單一 CMD；雙擊
`INSTALL_D_STOCK_ENV_FULL.cmd` 可執行核心、來源與驗證的完整流程，或用
`STOCK_SETUP_MANAGER.cmd` 的九項選單逐項操作。

先以唯讀模式確認狀態：

```cmd
INSTALL_D_STOCK_ENV.cmd /PREFLIGHT
INSTALL_D_STOCK_ENV_FULL.cmd /PREFLIGHT
VERIFY_STOCK_ENV.cmd
```

正式核心安裝固定使用 Python 3.10–3.12，優先 Python 3.12，並建立或沿用：

```text
D:\stock\GitHub\.venv
D:\stock\GitHub\repos
```

來源下載是獨立操作；使用 `DOWNLOAD_STOCK_SOURCES.cmd --check` 或
`DOWNLOAD_LEGACY_SOURCES.cmd --check` 只檢查，不會 clone、pull 或建立目錄。

`DOWNLOAD_LEGACY_SOURCES.cmd` 管理的 3 個 legacy identities 如下（不列入 37 primary）：

```text
mlouielu/twstock                    -> repos/taiwan_market_data/twstock
william911530-cmyk/python-stock-radar- -> repos/legacy_compat/python-stock-radar-
k66inthesky/TW-stock                -> repos/legacy_compat/TW-stock
```

## 舊路徑與 junction

相容路徑 `D:\Downloads\stock` 是 optional。安裝、完整安裝與驗證不會自動建立或修復 junction。
請先檢查範圍：

```cmd
REPAIR_STOCK_PATHS.cmd --check
```

只有確認輸出後，才可明確執行：

```cmd
REPAIR_STOCK_PATHS.cmd --apply --confirm
```

修復程式只處理列出的舊路徑與 `D:\stock\GitHub\repos` 內的相容連結；已存在的實體資料夾不會被覆蓋。
缺少來源時只顯示 `SKIP`，不會偷偷建立連結。

## 使用者環境變數

正式設定使用者環境變數：

```text
STOCK_HOME=D:\stock\GitHub
STOCK_REPO=D:\stock\GitHub
STOCK_SHARED_ROOT=D:\stock
STOCK_VENV=D:\stock\GitHub\.venv
STOCK_PYTHON=D:\stock\GitHub\.venv\Scripts\python.exe
STOCK_EXTERNAL_REPOS=D:\stock\GitHub\repos
PYTHONUTF8=1
PYTHONIOENCODING=utf-8
```

`CONFIGURE_WINDOWS_ENV.cmd /PREFLIGHT` 只顯示預計設定，不寫入 User PATH；正式設定後需重新開啟 CMD、PowerShell 或 VS Code。User PATH 管理的完整六項固定項目為：

```text
D:\stock\GitHub
D:\stock\GitHub\.venv\Scripts
D:\stock\GitHub\scripts
D:\stock\GitHub\scripts\setup
D:\stock\GitHub\scripts\sources
D:\stock\GitHub\scripts\compat
```

## 可直接雙擊的入口

| 檔案 | 功能 |
|---|---|
| `STOCK_SETUP_MANAGER.cmd` | 九項安裝、來源、修復、驗證與 venv 終端選單 |
| `INSTALL_D_STOCK_ENV.cmd` | 核心安裝；`/PREFLIGHT`、`/DRY-RUN` 只讀預覽，`/CHECK` 只做語法檢查 |
| `INSTALL_D_STOCK_ENV_FULL.cmd` | 核心環境後依序處理主要來源、legacy 來源與驗證；`/PREFLIGHT` 只讀 |
| `CONFIGURE_WINDOWS_ENV.cmd` | 設定 User env/PATH；`/PREFLIGHT` 只讀預覽 |
| `DOWNLOAD_STOCK_SOURCES.cmd` | 37 個主要來源；`--check`/`--dry-run` 只讀 |
| `DOWNLOAD_LEGACY_SOURCES.cmd` | 舊版相容來源；`--check`/`--dry-run` 只讀 |
| `REPAIR_STOCK_PATHS.cmd` | `--check` 只讀；`--apply --confirm` 才建立 junction |
| `VERIFY_STOCK_ENV.cmd` | 固定 root、origin/branch/dirty、Git、Python、venv、PATH、來源與 junction 唯讀驗證 |
| `OPEN_STOCK_TERMINAL.cmd` | 開啟 `D:\stock\GitHub\.venv` 已啟用的 CMD |

## 舊入口

`install_tw_stock_ai_env.cmd`、`scripts\clone_stock_analysis_repos.cmd`、
`requirements_tw_stock_ai.txt` 與根目錄 `external_stock_repositories.md` 保留為相容入口或舊文件；
新操作請使用 `STOCK_SETUP_MANAGER.cmd` 與 `docs\` 下的說明。

## 驗證

`VERIFY_STOCK_ENV.cmd` 不建立 log，也不修改 repository、`.venv`、User PATH、registry 或 junction。
它驗證 Git/Python/venv、`pip check`、28 個 direct requirements（含 import alias）、
六項 managed PATH、37 primary 與 3 legacy identities、origin 與 reparse safety。
AI／Agent 8 個研究來源為 optional。dirty worktree、未設定 optional legacy 路徑會列為
non-blocking warning；錯誤 origin、損壞 venv、必要 runtime 缺失或不在允許範圍的 target
才回傳 nonzero。Verifier 不跑正式全市場分析，也不證明第三方策略績效或盈利。

正式安裝可能由 Windows 顯示 UAC；Python 支援 3.10–3.12 且優先 3.12，`requirements.txt`
目前有 28 個 direct requirements。`--check`、`--dry-run` 與 `/PREFLIGHT` 都是唯讀，
不會 clone、pull、安裝套件、寫 User env 或建立 junction。
