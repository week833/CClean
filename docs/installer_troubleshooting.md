# 安裝程式閃退與舊安裝器說明

## 已修正的閃退問題

舊版 `INSTALL_D_STOCK_ENV.cmd` 在處理已存在且非 Git repository 的 `D:\stock` 時，包含一個不完整的批次判斷：

```cmd
if !ERRORLEVEL! NEQ (
```

缺少比較值 `0`，會觸發 CMD 語法錯誤，雙擊執行時可能只看到視窗短暫出現後關閉。

目前已改為：

- 根目錄 `INSTALL_D_STOCK_ENV.cmd` 只負責穩定啟動與保留視窗。
- 實際安裝邏輯移至 `scripts/setup/install_d_stock_env.ps1`。
- 發生錯誤時一定顯示錯誤碼並等待按鍵。
- 完整紀錄寫入 `%TEMP%\install_d_stock_env.log`。
- 不會因單獨下載一個 CMD 而自動補齊 PowerShell 核心；第一次使用必須從 GitHub
  下載完整 repository/package 並完整解壓，保留 `scripts/`、requirements 與
  manifest。缺少核心檔案時會 fail-closed 顯示路徑，不會從未知來源下載或執行。

## 第一次使用與固定 root

請從完整解壓後的 package 目錄雙擊：

```cmd
INSTALL_D_STOCK_ENV_FULL.cmd
```

或雙擊 `STOCK_SETUP_MANAGER.cmd` 選項 2。package 可以放在桌面或其他暫存目錄；
核心安裝完成並通過 identity 檢查後，所有 operational actions 只使用已驗證的
`D:\stock\GitHub`，不會繼續使用呼叫端複本。若固定 root 已存在但 origin 錯誤、
有錯誤的非空內容、Git metadata 不正確，或 root/managed path/source target 為
reparse point，流程會停止且不搬移、刪除或覆寫 `D:\stock` 其他項目。

`INSTALL_D_STOCK_ENV_FULL.cmd /PREFLIGHT`、`INSTALL_D_STOCK_ENV.cmd /PREFLIGHT`
與 `--check`/`--dry-run` 只讀；不會安裝、clone、pull、寫 User env 或建立 junction。

## 電腦中找到的舊版安裝器

舊版 `install_tw_stock_ai_env.cmd` 類型的安裝器（以下是歷史行為，不是目前 fixed-root
契約）可以：

- 建立 `D:\stock`。
- 建立 `D:\stock\.venv`。
- 安裝 FinMind、twstock、pandas、yfinance 等核心套件。
- 下載少量早期參考 repository。

但它不能完整達成目前需求，因為它不會：

- clone 或更新 `week833/stock` 到 `D:\stock`。
- 設定 `STOCK_HOME`、`STOCK_PYTHON`、`STOCK_VENV` 等 Windows 使用者環境變數。
- 將 `D:\stock\.venv\Scripts` 加入使用者 PATH。
- 建立 `D:\Downloads\stock -> D:\stock` 相容 junction。
- 依目前分類結構下載及管理完整外部來源。
- 驗證 CMD、PowerShell、VS Code、排程器等應用程式使用環境。

因此它只能作為核心 Python 套件的備用相容入口；完整安裝請使用完整 package 根目錄的：

```cmd
INSTALL_D_STOCK_ENV_FULL.cmd
```

Windows 可能仍會顯示 UAC；Git/Python 會優先使用已安裝的 Git、Python 3.12
(支援 3.10–3.12)，缺少時才依 `winget` 能力提出安裝。

## 建議排錯方式

不要直接依賴雙擊後消失的視窗。可以開啟 CMD 後執行：

```cmd
cd /d 下載安裝檔的資料夾
INSTALL_D_STOCK_ENV.cmd
```

若失敗，查看：

```text
%TEMP%\install_d_stock_env.log
```
