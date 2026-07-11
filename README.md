# 台股 AI 分析與量化研究工具庫

本 repository 已依用途與原始來源完成分類，並加入舊路徑相容機制，避免整理後原本使用中的程式因路徑改變而失效。

## 最簡單的使用方式

直接雙擊根目錄：

```cmd
STOCK_SETUP_MANAGER.cmd
```

可選擇：

1. 安裝 / 修復核心 Python 環境
2. 下載 / 更新全部分類來源
3. 下載舊版相容來源
4. 修復舊檔名與舊資料夾路徑
5. 完整建置全部環境
6. 檢查目前環境，不修改資料

建議先選 `[6]` 檢查；若環境正常，通常不需要重新安裝。

## 根目錄可雙擊執行檔

| 執行檔 | 用途 |
|---|---|
| [`STOCK_SETUP_MANAGER.cmd`](./STOCK_SETUP_MANAGER.cmd) | 統一安裝、下載、修復與檢查選單 |
| [`install_tw_stock_ai_env.cmd`](./install_tw_stock_ai_env.cmd) | 保留舊路徑的核心環境安裝入口 |
| [`DOWNLOAD_STOCK_SOURCES.cmd`](./DOWNLOAD_STOCK_SOURCES.cmd) | 下載 / 更新全部 36 個分類來源 |
| [`DOWNLOAD_LEGACY_SOURCES.cmd`](./DOWNLOAD_LEGACY_SOURCES.cmd) | 下載舊版安裝程式曾使用的額外來源 |
| [`REPAIR_STOCK_PATHS.cmd`](./REPAIR_STOCK_PATHS.cmd) | 修復舊資料夾與固定路徑相容性 |
| [`VERIFY_STOCK_ENV.cmd`](./VERIFY_STOCK_ENV.cmd) | 檢查核心檔案、虛擬環境與套件匯入 |

## 快速入口

| 內容 | 路徑 |
|---|---|
| 核心 Python 套件 | [`requirements.txt`](./requirements.txt) |
| 舊 requirements 檔名相容 | [`requirements_tw_stock_ai.txt`](./requirements_tw_stock_ai.txt) |
| 新版 Windows 環境安裝 | [`scripts/setup/install_tw_stock_ai_env.cmd`](./scripts/setup/install_tw_stock_ai_env.cmd) |
| 新版外部來源下載 / 更新 | [`scripts/sources/clone_stock_analysis_repos.cmd`](./scripts/sources/clone_stock_analysis_repos.cmd) |
| 舊版相容來源下載 | [`scripts/sources/clone_legacy_compat_repos.cmd`](./scripts/sources/clone_legacy_compat_repos.cmd) |
| 舊路徑修復 | [`scripts/compat/repair_legacy_paths.cmd`](./scripts/compat/repair_legacy_paths.cmd) |
| 環境檢查 | [`scripts/compat/verify_stock_environment.cmd`](./scripts/compat/verify_stock_environment.cmd) |
| 完整來源清單 | [`docs/external_stock_repositories.md`](./docs/external_stock_repositories.md) |
| 相容性說明 | [`docs/legacy_compatibility.md`](./docs/legacy_compatibility.md) |
| Repository 結構 | [`docs/repository_structure.md`](./docs/repository_structure.md) |
| 依來源分類的資料夾 | [`sources/`](./sources/) |

## 保留的舊路徑

以下原本的路徑已恢復，舊程式與舊操作方式可繼續使用：

```text
install_tw_stock_ai_env.cmd
scripts/clone_stock_analysis_repos.cmd
requirements_tw_stock_ai.txt
external_stock_repositories.md
```

這些檔案會自動轉交到新的分類路徑。

## 既有環境不會被刪除

核心環境安裝程式會：

- 沿用現有 `.venv`
- 不刪除原虛擬環境
- 補裝 `requirements.txt` 中缺少的套件
- 完成後自動執行舊路徑修復

只有 `.venv` 不存在或套件檢查失敗時，才需要重新安裝。

## 外部來源分類

目前共整理 **36 個** 股票分析相關 GitHub 來源：

1. [`01_taiwan_stock_data`](./sources/01_taiwan_stock_data/)：台股資料與既有分析工具
2. [`02_market_data_platforms`](./sources/02_market_data_platforms/)：金融資料與市場研究平台
3. [`03_ai_ml_forecasting`](./sources/03_ai_ml_forecasting/)：AI、ML 與時間序列預測
4. [`04_backtesting_engines`](./sources/04_backtesting_engines/)：回測與策略測試
5. [`05_indicators_factors_portfolio`](./sources/05_indicators_factors_portfolio/)：指標、因子、績效與投組風控

每個來源都有自己的資料夾與說明，不會互相混放。

## 下載來源後的實際位置

```text
external_repos/
├─ 01_taiwan_stock_data/
├─ 02_market_data_platforms/
├─ 03_ai_ml_forecasting/
├─ 04_backtesting_engines/
├─ 05_indicators_factors_portfolio/
└─ 00_legacy_compat/
```

新版下載器若發現舊資料位於：

```text
external_repos/<來源>/
github_sources/<來源>/
```

會優先搬移到新的分類資料夾，避免重新下載。

`REPAIR_STOCK_PATHS.cmd` 會再建立舊路徑相容連結，例如：

```text
external_repos/FinMind
external_repos/qlib
github_sources/twstock
```

使原本使用舊路徑的程式仍可執行。

若 repository 不在 `D:\Downloads\stock`，修復程式也會在安全條件符合時嘗試建立：

```text
D:\Downloads\stock -> 目前 repository 位置
```

已存在的實體資料夾不會被覆蓋。

## 手動安裝核心環境

```cmd
py -3 -m venv .venv
.venv\Scripts\activate
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
```

## 安全提醒

不要提交：

- `.env`、API Token、金鑰
- `.venv/`
- log、cache、產出報告
- `external_repos/` 與 `github_sources/` 內的第三方原始碼

大型框架建議使用各自的獨立虛擬環境，以避免版本衝突。
