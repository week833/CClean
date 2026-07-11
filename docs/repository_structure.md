# Repository 結構

```text
stock/
├─ README.md
├─ .gitignore
├─ requirements.txt
├─ docs/
│  ├─ repository_structure.md
│  └─ external_stock_repositories.md
├─ scripts/
│  ├─ setup/
│  │  └─ install_tw_stock_ai_env.cmd
│  └─ sources/
│     └─ clone_stock_analysis_repos.cmd
├─ sources/
│  ├─ 01_taiwan_stock_data/
│  ├─ 02_market_data_platforms/
│  ├─ 03_ai_ml_forecasting/
│  ├─ 04_backtesting_engines/
│  └─ 05_indicators_factors_portfolio/
└─ external_repos/                 # 本機 clone 內容，不提交 GitHub
```

## 整理原則

- 根目錄只保留 GitHub 慣例入口檔：`README.md`、`.gitignore`、`requirements.txt`。
- 安裝與下載工具集中於 `scripts/`。
- 說明文件集中於 `docs/`。
- 每個外部來源在 `sources/<分類>/<來源>/README.md` 有獨立說明。
- 真正的外部原始碼 clone 到 `external_repos/<分類>/<來源>/`，並由 `.gitignore` 排除。
- 不把不同第三方專案混在同一資料夾，也不將其原始碼重新提交至本 repo。
