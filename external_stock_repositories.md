# 外部股票分析 GitHub 來源清單

本檔案紀錄可供台股 / 股票分析 / 量化研究 / 預測模型參考的外部 GitHub repository。

> 注意：這裡只保存來源清單與下載指令，沒有把外部專案完整原始碼直接複製進本 repo。使用前請自行確認各專案的授權條款、維護狀態、資料限制與相依套件版本。

## 已加入來源

### A. 台股與股票資料 / 既有參考來源

| 類別 | Repository | Default branch | Clone URL | 用途建議 |
|---|---|---:|---|---|
| 金融資料 API / 台股資料 | `FinMind/FinMind` | `master` | `https://github.com/FinMind/FinMind.git` | 台股股價、法人、基本面、新聞、期貨選擇權等資料來源。 |
| 每日股票分析 | `ZhuLinsen/daily_stock_analysis` | `main` | `https://github.com/ZhuLinsen/daily_stock_analysis.git` | 可參考每日分析流程、報告產生與資料整理方式。 |
| 策略範例 | `kevin801221/stock-strategies-only` | `main` | `https://github.com/kevin801221/stock-strategies-only.git` | 可參考交易策略、選股邏輯與策略檔案組織。 |
| 市場分析工具 | `sacahan/CasualMarket` | `main` | `https://github.com/sacahan/CasualMarket.git` | 可參考市場分析工具與資料處理架構。 |
| 台股資料抓取 | `mlouielu/twstock` | `dev` | `https://github.com/mlouielu/twstock.git` | 台灣股市股票價格擷取工具，可作為台股資料備援。 |
| Python 股票教學 | `victorgau/PyConTW2018Tutorial` | `master` | `https://github.com/victorgau/PyConTW2018Tutorial.git` | 可參考 Python 金融資料分析與教學範例。 |

### B. AI / ML / 量化研究與預測框架

| 類別 | Repository | Default branch | Clone URL | 用途建議 |
|---|---|---:|---|---|
| AI 量化研究平台 | `microsoft/qlib` | `main` | `https://github.com/microsoft/qlib.git` | 可參考資料處理、因子建模、模型訓練、回測、投組建構與 AI 量化研究流程。 |
| 強化學習交易框架 | `AI4Finance-Foundation/FinRL` | `master` | `https://github.com/AI4Finance-Foundation/FinRL.git` | 可參考 DRL 交易代理、交易環境、持倉決策與模型訓練架構。 |
| 金融資料 / 研究平台 | `OpenBB-finance/OpenBB` | `develop` | `https://github.com/OpenBB-finance/OpenBB.git` | 可參考金融資料整合、研究終端、API 與 agent 化金融分析架構。 |
| 加密貨幣交易 bot / ML 參考 | `freqtrade/freqtrade` | `develop` | `https://github.com/freqtrade/freqtrade.git` | 雖以加密貨幣為主，但可參考策略最佳化、回測、風控、FreqAI 與交易系統架構。 |

### C. 回測引擎 / 策略測試

| 類別 | Repository | Default branch | Clone URL | 用途建議 |
|---|---|---:|---|---|
| 高速向量化回測 | `polakowo/vectorbt` | `master` | `https://github.com/polakowo/vectorbt.git` | 適合大量測試技術指標、停利停損、參數組合與多標的策略。 |
| 輕量股票回測 | `kernc/backtesting.py` | `master` | `https://github.com/kernc/backtesting.py.git` | 適合快速驗證單一策略邏輯、K 線進出場與參數最佳化。 |
| 專業級交易引擎 | `QuantConnect/Lean` | `master` | `https://github.com/QuantConnect/Lean.git` | 可參考完整事件驅動交易系統、回測、最佳化、live trading 與演算法交易架構。 |
| 組合型策略回測 | `pmorissette/bt` | `master` | `https://github.com/pmorissette/bt.git` | 適合多標的資金配置、輪動策略、權重調整與策略模組化。 |
| Zipline 維護版 | `stefan-jansen/zipline-reloaded` | `main` | `https://github.com/stefan-jansen/zipline-reloaded.git` | 可參考事件驅動式回測流程、performance DataFrame 與歷史資料匯入。 |
| 經典 Python 回測框架 | `mementum/backtrader` | `master` | `https://github.com/mementum/backtrader.git` | 可參考策略、broker、indicator、analyzer 架構；注意 GPL-3.0 授權相容性。 |

### D. 技術指標 / 績效報告 / 投組最佳化

| 類別 | Repository | Default branch | Clone URL | 用途建議 |
|---|---|---:|---|---|
| Yahoo Finance 資料來源 | `ranaroussi/yfinance` | `main` | `https://github.com/ranaroussi/yfinance.git` | 可作為台股 `.TW` / `.TWO` 價量資料與國際市場資料備援。 |
| 技術指標 / 特徵工程 | `bukosabino/ta` | `master` | `https://github.com/bukosabino/ta.git` | 可直接增加 momentum、trend、volatility、volume 等技術指標特徵。 |
| 績效分析 / 報表 | `ranaroussi/quantstats` | `main` | `https://github.com/ranaroussi/quantstats.git` | 可參考勝率、Sharpe、最大回撤、績效圖表與 HTML tear sheet。 |
| 投資組合最佳化 | `skfolio/skfolio` | `main` | `https://github.com/skfolio/skfolio.git` | 可參考資產配置、風險控管、交叉驗證、HRP、Risk Budgeting 與壓力測試。 |

## 建議整合順序

1. **先補強現有程式**：`yfinance`、`ta`、`quantstats`、`backtesting.py`。
2. **建立正式回測流程**：`vectorbt`、`bt`、`zipline-reloaded`。
3. **升級 AI / ML 模型**：`qlib`、`FinRL`、`skfolio`。
4. **參考大型系統架構**：`Lean`、`OpenBB`、`freqtrade`。

## 一鍵下載

Windows 使用者可以執行：

```cmd
scripts\clone_stock_analysis_repos.cmd
```

預設會下載到：

```txt
external_repos/
```

若資料夾已存在，腳本會嘗試 `git pull` 更新；若不存在，會執行 `git clone`。

## 手動下載指令

```cmd
git clone https://github.com/FinMind/FinMind.git external_repos\FinMind
git clone https://github.com/ZhuLinsen/daily_stock_analysis.git external_repos\daily_stock_analysis
git clone https://github.com/kevin801221/stock-strategies-only.git external_repos\stock-strategies-only
git clone https://github.com/sacahan/CasualMarket.git external_repos\CasualMarket
git clone https://github.com/mlouielu/twstock.git external_repos\twstock
git clone https://github.com/victorgau/PyConTW2018Tutorial.git external_repos\PyConTW2018Tutorial
git clone https://github.com/microsoft/qlib.git external_repos\qlib
git clone https://github.com/AI4Finance-Foundation/FinRL.git external_repos\FinRL
git clone https://github.com/polakowo/vectorbt.git external_repos\vectorbt
git clone https://github.com/kernc/backtesting.py.git external_repos\backtesting.py
git clone https://github.com/QuantConnect/Lean.git external_repos\Lean
git clone https://github.com/OpenBB-finance/OpenBB.git external_repos\OpenBB
git clone https://github.com/ranaroussi/yfinance.git external_repos\yfinance
git clone https://github.com/bukosabino/ta.git external_repos\ta
git clone https://github.com/ranaroussi/quantstats.git external_repos\quantstats
git clone https://github.com/skfolio/skfolio.git external_repos\skfolio
git clone https://github.com/pmorissette/bt.git external_repos\bt
git clone https://github.com/stefan-jansen/zipline-reloaded.git external_repos\zipline-reloaded
git clone https://github.com/mementum/backtrader.git external_repos\backtrader
git clone https://github.com/freqtrade/freqtrade.git external_repos\freqtrade
```

## 大型 repo 注意事項

以下來源體積較大，下載時間可能較久：

- `OpenBB-finance/OpenBB`
- `polakowo/vectorbt`
- `QuantConnect/Lean`
- `freqtrade/freqtrade`
- `stefan-jansen/zipline-reloaded`

若只想快速補強現有台股程式，可先下載：

```cmd
git clone https://github.com/ranaroussi/yfinance.git external_repos\yfinance
git clone https://github.com/bukosabino/ta.git external_repos\ta
git clone https://github.com/ranaroussi/quantstats.git external_repos\quantstats
git clone https://github.com/kernc/backtesting.py.git external_repos\backtesting.py
```
