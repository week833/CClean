# 台股 AI 分析環境

這個 repository 目前用來保存台股 AI 分析程式的 Python 套件清單、Windows 自動安裝程式，以及外部股票分析 / 量化研究 / 預測模型 GitHub 參考來源。

## 內容

- `requirements.txt`：台股分析、資料抓取、報表輸出常用 Python 套件清單。
- `install_tw_stock_ai_env.cmd`：Windows 可雙擊執行的自動安裝程式。
- `external_stock_repositories.md`：外部股票分析 GitHub repository 清單。
- `scripts/clone_stock_analysis_repos.cmd`：一鍵下載 / 更新外部股票分析 repository 的 Windows 腳本。
- `.gitignore`：避免上傳 `.venv`、`.env`、log、cache、外部 clone repo 等不該進 GitHub 的檔案。

## 自動安裝方式

在 Windows 上下載本 repo 後，直接執行：

```cmd
install_tw_stock_ai_env.cmd
```

安裝程式會自動：

1. 建立 `D:\Downloads\stock`
2. 建立 Python 虛擬環境 `.venv`
3. 安裝台股分析常用套件
4. 測試主要套件是否可正常匯入
5. 若電腦有安裝 Git，會自動 clone 幾個台股相關 GitHub 參考專案

## 手動安裝方式

```cmd
cd /d D:\Downloads\stock
py -3 -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
```

## 外部股票分析 GitHub 來源

目前已加入 **20 個** 外部參考來源，分成四類：

### 台股與股票資料 / 既有參考來源

- `FinMind/FinMind`
- `ZhuLinsen/daily_stock_analysis`
- `kevin801221/stock-strategies-only`
- `sacahan/CasualMarket`
- `mlouielu/twstock`
- `victorgau/PyConTW2018Tutorial`

### AI / ML / 量化研究與預測框架

- `microsoft/qlib`
- `AI4Finance-Foundation/FinRL`
- `OpenBB-finance/OpenBB`
- `freqtrade/freqtrade`

### 回測引擎 / 策略測試

- `polakowo/vectorbt`
- `kernc/backtesting.py`
- `QuantConnect/Lean`
- `pmorissette/bt`
- `stefan-jansen/zipline-reloaded`
- `mementum/backtrader`

### 技術指標 / 績效報告 / 投組最佳化

- `ranaroussi/yfinance`
- `bukosabino/ta`
- `ranaroussi/quantstats`
- `skfolio/skfolio`

完整清單、用途說明、default branch 與手動 clone 指令請看：

```txt
external_stock_repositories.md
```

Windows 一鍵下載 / 更新全部外部來源：

```cmd
scripts\clone_stock_analysis_repos.cmd
```

外部專案會下載到：

```txt
external_repos/
```

> 注意：本 repo 只保存來源清單與 clone 腳本，沒有直接複製外部專案完整原始碼。使用前請自行確認各專案授權條款、資料限制與相依套件版本。

## 建議整合順序

1. **先補強現有程式**：`yfinance`、`ta`、`quantstats`、`backtesting.py`。
2. **建立正式回測流程**：`vectorbt`、`bt`、`zipline-reloaded`。
3. **升級 AI / ML 模型**：`qlib`、`FinRL`、`skfolio`。
4. **參考大型系統架構**：`Lean`、`OpenBB`、`freqtrade`。

## 主要套件

目前 `requirements.txt` 包含：

- `FinMind`
- `twstock`
- `pandas`
- `numpy`
- `yfinance`
- `requests`
- `feedparser`
- `beautifulsoup4`
- `lxml`
- `matplotlib`
- `exchange_calendars`
- `ta`
- `openpyxl`
- `xlsxwriter`
- `reportlab`

大型量化框架如 `qlib`、`FinRL`、`OpenBB`、`Lean`、`freqtrade` 不建議直接加入主 requirements，因為相依套件較重，且可能與現有環境版本衝突。建議先透過 `external_repos/` 下載參考，確認要整合哪一個後再單獨建立環境。

## 重要提醒

不要把以下檔案上傳到 GitHub：

```txt
.venv/
.env
*.log
__pycache__/
external_repos/
```

`.env` 可能包含 FinMind Token 或其他 API Key，務必保留在本機。

`.env` 範例：

```env
FINMIND_TOKEN=你的FinMindToken
ANTHROPIC_API_KEY=你的APIKey
```
