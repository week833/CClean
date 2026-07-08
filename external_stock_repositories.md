# 外部股票分析 GitHub 來源清單

本檔案紀錄可供台股 / 股票分析程式參考的外部 GitHub repository。

> 注意：這裡只保存來源清單與下載指令，沒有把外部專案完整原始碼直接複製進本 repo。使用前請自行確認各專案的授權條款、維護狀態與相依套件版本。

## 已加入來源

| 類別 | Repository | Default branch | Clone URL | 用途建議 |
|---|---|---:|---|---|
| 金融資料 API / 台股資料 | `FinMind/FinMind` | `master` | `https://github.com/FinMind/FinMind.git` | 台股股價、法人、基本面、新聞、期貨選擇權等資料來源。 |
| 每日股票分析 | `ZhuLinsen/daily_stock_analysis` | `main` | `https://github.com/ZhuLinsen/daily_stock_analysis.git` | 可參考每日分析流程、報告產生與資料整理方式。 |
| 策略範例 | `kevin801221/stock-strategies-only` | `main` | `https://github.com/kevin801221/stock-strategies-only.git` | 可參考交易策略、選股邏輯與策略檔案組織。 |
| 市場分析工具 | `sacahan/CasualMarket` | `main` | `https://github.com/sacahan/CasualMarket.git` | 可參考市場分析工具與資料處理架構。 |
| 台股資料抓取 | `mlouielu/twstock` | `dev` | `https://github.com/mlouielu/twstock.git` | 台灣股市股票價格擷取工具，可作為台股資料備援。 |
| Python 股票教學 | `victorgau/PyConTW2018Tutorial` | `master` | `https://github.com/victorgau/PyConTW2018Tutorial.git` | 可參考 Python 金融資料分析與教學範例。 |

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
```
