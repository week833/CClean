# Windows 安裝包契約與驗證範圍

## 交付方式

第一次使用者必須從 GitHub 下載本 repository 的完整 package（完整 ZIP 解壓或
Git clone）。不能只下載一個 `.cmd`：核心 PowerShell、source manifest、tests
與 `requirements.txt` 都是安裝包的一部分，缺檔時應停止而不是從未驗證來源抓取。

可從任意暫存資料夾雙擊 `INSTALL_D_STOCK_ENV_FULL.cmd` 執行完整流程，或雙擊
`STOCK_SETUP_MANAGER.cmd` 使用八項選單：

1. Preflight/dry-run（唯讀）。
2. Complete installation（Git/Python、venv、28 direct requirements、User env/PATH，完成後預設下載 3 個 core primary 與 2 個 unique legacy compatibility 來源並驗證）。
3. Download primary research sources（預設 3 個 core；`--all` 才是全部 37 個 primary）。
4. Download legacy sources（2 個 unique legacy，並檢查共享的 `twstock` alias）。
5. Repair legacy paths（先 `--check`，再由使用者明確確認 `--apply --confirm`）。
6. Reconfigure User environment and PATH。
7. Verify installed environment（唯讀）。
8. Open managed venv terminal。

完整安裝在核心成功後才叫用固定 root 下的 source/verify scripts；來源階段固定先處理 3 個 core primary、2 個 unique legacy，再驗證，全部 37 個 primary 必須由選單的 `--all` 明確 opt-in。呼叫端 package
可在其他資料夾，但 operational actions 不會寫入呼叫端複本。

## 固定位置與 fail-closed 邊界

正式 root 永遠是：

```text
D:\stock\GitHub
```

安裝器會拒絕下列情況並保留現場：

- root 不是預期的 `week833/stock` Git repository，或 normalized origin identity 不符；
- root 內有不受管理的錯誤非空內容、錯誤 `.git` metadata 或不完整 `.venv`；
- root、`.git`、`.venv`、scripts、repos、來源 target 或其祖先是 reparse point，
  或解析後離開 fixed scope。

任何拒絕都不會搬移、刪除、改名或覆寫 `D:\stock` 的其他資料。

## Runtime 與 Windows 設定

- Git for Windows：先使用既有可執行檔；缺少且 `winget` 可用時，才依固定 package
  identity 提出安裝。`GIT_TERMINAL_PROMPT=0` 防止來源流程等待認證輸入。
- Python：支援 3.10–3.12，優先 3.12；建立或沿用
  `D:\stock\GitHub\.venv`，不刪除不完整或可疑的既有環境。
- `requirements.txt` 現有 28 個 direct requirements；驗證會同時檢查 distribution
  metadata、import alias、`pip check`。
- User environment 變數：`STOCK_HOME`、`STOCK_REPO`、`STOCK_SHARED_ROOT`、
  `STOCK_VENV`、`STOCK_PYTHON`、`STOCK_EXTERNAL_REPOS`。
- User PATH 六項固定路徑：

  ```text
  D:\stock\GitHub
  D:\stock\GitHub\.venv\Scripts
  D:\stock\GitHub\scripts
  D:\stock\GitHub\scripts\setup
  D:\stock\GitHub\scripts\sources
  D:\stock\GitHub\scripts\compat
  ```

Windows 可能顯示 UAC；安裝後要重新開啟 CMD、PowerShell、VS Code 或排程器，才會
讀到新的 User env/PATH。

## Source safety contract

`--check`、`--dry-run`、`/PREFLIGHT` 全部唯讀：不建立目錄、不 clone、不 pull、不安裝
套件、不寫 User env、不寫 Git config、不建立 junction。正式來源僅在既有 repository
為 clean 且 normalized exact origin identity 符合時執行 `git pull --ff-only`；dirty
repository skip，錯 origin 或非 Git 目標 fail-closed。新 clone 先建立在 canonical
repos scope 的 temporary sibling，clone 後驗證 origin，再以 atomic rename 成為 target；
失敗時不覆蓋既有資料。

## Verifier coverage 與限制

`VERIFY_STOCK_ENV.cmd` 只做唯讀環境驗證，涵蓋 fixed-root/reparse safety、Git/origin、
dirty 狀態、venv Python/pip、`pip check`、28 direct imports、六項 managed PATH、37
primary、2 個 unique legacy 與共享 alias、既有 junction 參考。AI／Agent research entries
不屬於 installer manifest，也不是正式來源 gate。

Verifier 不會執行正式全市場分析、資料回補、三竹同步或第三方策略；通過它也不代表
回測命中率、MAE、盈利能力、風險或任何第三方 repository 的策略品質已被證明。

## CI 與本機 acceptance

GitHub Actions 只在 Windows PowerShell 5.1 的 temporary fixture 中跑 preflight、
fixed-root binding、source safety/write-mode、`Test-VerifyStockEnvironment.ps1`、
`Test-RepairLegacyPathsSafety.ps1` 與 `Test-InstallerIntegration -CiMode`。其中
`Test-RepairLegacyPathsSafety.ps1` 只在 disposable TEMP fixture 內驗證 `--check`、
reparse rejection 與已確認的 `--apply --confirm`；CI 絕不對 production root 或
`REPAIR_STOCK_PATHS.cmd` 做 apply。CI 不執行 production `VERIFY_STOCK_ENV.cmd`、
來源下載、winget、pip install、正式分析或 User env 寫入。

本機已安裝 acceptance 仍須另外在使用者明確授權下，以固定 root 的唯讀驗證檢查實際
Git/Python/venv/User PATH/來源狀態；CI fixture 通過不能取代本機 installed acceptance。
