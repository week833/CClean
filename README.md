# 台股 AI 分析環境

這個 repository 目前用來保存台股 AI 分析程式的 Python 套件清單與 Windows 自動安裝程式。

## 內容

- `requirements.txt`：台股分析、資料抓取、報表輸出常用 Python 套件清單。
- `install_tw_stock_ai_env.cmd`：Windows 可雙擊執行的自動安裝程式。
- `.gitignore`：避免上傳 `.venv`、`.env`、log、cache 等不該進 GitHub 的檔案。

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

## 主要套件

包含：

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

## 重要提醒

不要把以下檔案上傳到 GitHub：

```txt
.venv/
.env
*.log
__pycache__/
```

`.env` 可能包含 FinMind Token 或其他 API Key，務必保留在本機。

`.env` 範例：

```env
FINMIND_TOKEN=你的FinMindToken
ANTHROPIC_API_KEY=你的APIKey
```
