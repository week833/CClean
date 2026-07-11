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
- 若從 GitHub 單獨下載 CMD，啟動器會自動下載最新 PowerShell 安裝核心。

## 電腦中找到的舊版安裝器

舊版 `install_tw_stock_ai_env.cmd` 類型的安裝器可以：

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

因此它只能作為核心 Python 套件的備用安裝器；完整安裝請使用根目錄的：

```cmd
INSTALL_D_STOCK_ENV.cmd
```

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
