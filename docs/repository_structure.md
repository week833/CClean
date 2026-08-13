# Repository 結構

```text
stock/
├─ README.md
├─ .gitignore
├─ requirements.txt
├─ requirements_tw_stock_ai.txt          # 舊檔名相容入口
├─ STOCK_SETUP_MANAGER.cmd                # 統一安裝 / 下載 / 修復 / 檢查選單
├─ install_tw_stock_ai_env.cmd            # 舊根目錄安裝路徑相容入口
├─ DOWNLOAD_STOCK_SOURCES.cmd
├─ DOWNLOAD_LEGACY_SOURCES.cmd
├─ REPAIR_STOCK_PATHS.cmd
├─ VERIFY_STOCK_ENV.cmd
├─ CONFIGURE_WINDOWS_ENV.cmd
├─ OPEN_STOCK_TERMINAL.cmd
├─ RUN_STOCK_PYTHON.cmd
├─ RECOVER_MOVED_STOCK_PROGRAMS.cmd
├─ external_stock_repositories.md         # 舊文件路徑相容入口
│
├─ docs/
│  ├─ repository_structure.md
│  ├─ external_stock_repositories.md
│  ├─ legacy_compatibility.md
│  └─ windows_installer_package.md
│
├─ scripts/
│  ├─ clone_stock_analysis_repos.cmd      # 舊 scripts 路徑相容入口
│  ├─ setup/
│  │  ├─ install_tw_stock_ai_env.cmd
│  │  ├─ install_d_stock_env.ps1
│  │  ├─ assert_fixed_install_root.ps1
│  │  └─ tests/
│  │     ├─ Test-InstallerPreflight.ps1
│  │     └─ Test-EntrypointRootBinding.ps1
│  ├─ sources/
│  │  ├─ clone_stock_analysis_repos.cmd
│  │  ├─ clone_legacy_compat_repos.cmd
│  │  └─ tests/
│  │     └─ test_source_manager_fixtures.ps1
│  └─ compat/
│     ├─ repair_legacy_paths.cmd
│     ├─ verify_python_packages.py
│     ├─ verify_stock_environment.cmd
│     └─ tests/
│        └─ Test-VerifyStockEnvironment.ps1

├─ tests/
│  └─ installer/
│     └─ Test-InstallerIntegration.ps1
│
├─ sources/
│  ├─ taiwan_market_data/
│  ├─ global_market_data/
│  ├─ machine_learning_forecasting/
│  ├─ backtesting_engines/
│  ├─ quant_portfolio_risk/
│  └─ ai_agent_tools/
│
├─ repos/                        # 本機 clone 內容，不提交 GitHub
│  ├─ legacy_compat/
│  ├─ taiwan_market_data/
│  ├─ global_market_data/
│  ├─ machine_learning_forecasting/
│  ├─ backtesting_engines/
│  ├─ quant_portfolio_risk/
│  └─ ai_agent_tools/
│
└─ github_sources/                        # 早期路徑相容連結，不提交 GitHub
```

## 整理原則

- 根目錄保留 GitHub 入口檔與可直接雙擊的 Windows 啟動器。
- 真正執行邏輯集中於 `scripts/`，根目錄檔案主要負責相容轉接。
- 說明文件集中於 `docs/`，但保留舊文件路徑轉接。
- 每個外部來源在 `sources/<分類>/<來源>/README.md` 有獨立說明。
- 真正的外部原始碼 clone 到 `repos/<分類>/<來源>/`，並由 `.gitignore` 排除。
- AI／Agent 研究來源集中於 `repos/ai_agent_tools/`；不屬於正式股票推薦輸入。
- 舊的 `repos/<來源>/` 與 `github_sources/<來源>/` 透過 junction 指向新分類位置。
- 既有頂層 AI 工具與 `stocktw` 路徑也保留 junction，指向新的分類位置。
- 不覆蓋既有實體資料夾，不刪除既有 `.venv`，也不把不同第三方專案混在同一資料夾。
- package 可從任意解壓位置啟動；核心完成後 operational wrapper 僅綁定已驗證的
  `D:\stock\GitHub`，避免從呼叫端複本寫入錯誤目錄。
- root、`.git`、`.venv`、scripts、repos、來源 target 及祖先若是 reparse point，
  由 fixed-root/source safety gate fail-closed；不以文件或 junction 繞過檢查。

## 主要相容入口

以下路徑整理前後都能使用：

```text
install_tw_stock_ai_env.cmd
scripts/clone_stock_analysis_repos.cmd
requirements_tw_stock_ai.txt
external_stock_repositories.md
```

推薦新的統一入口：

```text
STOCK_SETUP_MANAGER.cmd
```
