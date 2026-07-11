# 台股 AI 分析與量化研究工具庫

本 repository 已依用途與原始來源完成分類，避免不同 GitHub 專案、安裝腳本與說明文件混在一起。

## 快速入口

| 內容 | 路徑 |
|---|---|
| 核心 Python 套件 | [`requirements.txt`](./requirements.txt) |
| Windows 環境安裝 | [`scripts/setup/install_tw_stock_ai_env.cmd`](./scripts/setup/install_tw_stock_ai_env.cmd) |
| 外部來源一鍵下載 / 更新 | [`scripts/sources/clone_stock_analysis_repos.cmd`](./scripts/sources/clone_stock_analysis_repos.cmd) |
| 完整來源清單 | [`docs/external_stock_repositories.md`](./docs/external_stock_repositories.md) |
| Repository 結構說明 | [`docs/repository_structure.md`](./docs/repository_structure.md) |
| 依來源分類的資料夾 | [`sources/`](./sources/) |

## 外部來源分類

目前共整理 **36 個** 股票分析相關 GitHub 來源：

1. [`01_taiwan_stock_data`](./sources/01_taiwan_stock_data/)：台股資料與既有分析工具
2. [`02_market_data_platforms`](./sources/02_market_data_platforms/)：金融資料與市場研究平台
3. [`03_ai_ml_forecasting`](./sources/03_ai_ml_forecasting/)：AI、ML 與時間序列預測
4. [`04_backtesting_engines`](./sources/04_backtesting_engines/)：回測與策略測試
5. [`05_indicators_factors_portfolio`](./sources/05_indicators_factors_portfolio/)：指標、因子、績效與投組風控

每個來源都有自己的資料夾與說明，不會互相混放。

## 安裝核心環境

```cmd
scripts\setup\install_tw_stock_ai_env.cmd
```

或手動安裝：

```cmd
py -3 -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
```

## 下載全部外部來源

```cmd
scripts\sources\clone_stock_analysis_repos.cmd
```

外部原始碼會依分類下載到：

```text
external_repos/
├─ 01_taiwan_stock_data/
├─ 02_market_data_platforms/
├─ 03_ai_ml_forecasting/
├─ 04_backtesting_engines/
└─ 05_indicators_factors_portfolio/
```

`external_repos/` 已加入 `.gitignore`，避免把第三方原始碼整包提交回本 repository。

## 安全提醒

不要提交：

- `.env`、API Token、金鑰
- `.venv/`
- log、cache、產出報告
- `external_repos/` 內的第三方原始碼

大型框架建議使用各自的獨立虛擬環境，以避免版本衝突。
