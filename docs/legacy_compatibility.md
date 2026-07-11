# 舊路徑與既有環境相容說明

本 repository 已重新分類，但保留舊入口與舊資料夾相容機制，目的是避免原本程式因路徑改變而失效。

## 建議先執行

雙擊根目錄：

```cmd
STOCK_SETUP_MANAGER.cmd
```

建議順序：

1. 先選 `[6] 只檢查目前環境`。
2. 若核心套件正常，不需要重新安裝。
3. 若只發生路徑找不到，選 `[4] 修復舊檔名與舊資料夾路徑`。
4. 只有缺少 `.venv` 或套件匯入失敗時，才選 `[1] 安裝 / 修復核心 Python 環境`。
5. 只有外部 GitHub 原始碼缺少時，才選 `[2]` 或 `[3]` 下載。

## 保留的舊檔案路徑

以下舊入口仍可繼續使用：

```text
install_tw_stock_ai_env.cmd
scripts/clone_stock_analysis_repos.cmd
requirements_tw_stock_ai.txt
external_stock_repositories.md
```

它們會自動轉交到新的分類位置，不需要修改原本使用方式。

## 可直接雙擊的程式

| 檔案 | 功能 |
|---|---|
| `STOCK_SETUP_MANAGER.cmd` | 統一選單：安裝、下載、修復、檢查或完整建置 |
| `install_tw_stock_ai_env.cmd` | 舊路徑相容的核心環境安裝程式 |
| `DOWNLOAD_STOCK_SOURCES.cmd` | 下載 / 更新全部 36 個分類來源 |
| `DOWNLOAD_LEGACY_SOURCES.cmd` | 下載舊安裝程式曾使用的額外來源 |
| `REPAIR_STOCK_PATHS.cmd` | 建立舊資料夾到新資料夾的相容連結 |
| `VERIFY_STOCK_ENV.cmd` | 檢查核心檔案、`.venv` 與套件匯入狀態 |

## 既有 `.venv` 的處理

安裝程式不會刪除既有 `.venv`。若虛擬環境已存在，會直接沿用並補裝 `requirements.txt` 中缺少的套件。

因此一般不需要先刪除環境，也不需要每次重新建立。

## 外部來源舊路徑

新版來源實際存放於：

```text
external_repos/<分類>/<來源>/
```

修復程式會建立舊版平面路徑，例如：

```text
external_repos/FinMind
external_repos/qlib
external_repos/vectorbt
```

並指向新的分類資料夾，讓舊程式仍能沿用原路徑。

早期安裝程式使用的：

```text
github_sources/twstock
github_sources/tw_stocker
github_sources/python-stock-radar-
github_sources/TW-stock
```

也會建立相容連結。

## 舊固定位置 `D:\Downloads\stock`

若 repository 不在 `D:\Downloads\stock`，且該位置尚不存在，修復程式會嘗試建立目錄連結：

```text
D:\Downloads\stock -> 目前 repository 位置
```

若建立失敗，可對 `REPAIR_STOCK_PATHS.cmd` 按右鍵選擇「以系統管理員身分執行」。

若 `D:\Downloads\stock` 已有實體資料，程式不會覆蓋或刪除。

## 舊下載資料自動搬移

新版來源下載器會先檢查：

```text
external_repos/<來源>/
github_sources/<來源>/
```

若找到既有 Git repository，而新的分類位置尚未建立，會直接搬移到分類資料夾，避免重新下載。

## 安全原則

相容修復程式：

- 不刪除既有實體資料夾。
- 不覆蓋已存在的舊路徑。
- 尚未下載的來源只顯示 `SKIP`。
- 第三方原始碼仍由 `.gitignore` 排除，不會誤提交到此 repository。
