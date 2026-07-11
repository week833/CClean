# `.env` 安全建立與復原

正式位置：

```text
D:\stock\GitHub\.env
```

## 執行工具

雙擊 repository 根目錄的：

```cmd
CREATE_OR_RECOVER_ENV.cmd
```

工具提供三種操作：

1. 從先前備份中復原 `.env`。
2. 使用隱藏輸入重新建立 `.env`。
3. 保留目前 `.env`，不做修改。

## 自動搜尋範圍

復原模式會搜尋：

```text
D:\stock\.env
D:\Downloads\stock\.env
D:\stock_backup_*\...\.env
D:\stock\Recovered_from_previous_installer_*\...\.env
```

只會列出路徑與修改時間，不會顯示 `.env` 內容。

## 預設環境變數

重新建立模式會處理：

```text
STOCK_HOME=D:\stock\GitHub
STOCK_EXTERNAL_REPOS=D:\stock\GitHub\external_repos
PYTHONUTF8=1
PYTHONIOENCODING=utf-8
TZ=Asia/Taipei
FINMIND_AUTH_MODE=header
FINMIND_TOKEN=
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
```

金鑰使用 PowerShell 隱藏輸入，不會顯示在畫面或寫入 log。也可以加入其他自訂環境變數。

## 覆蓋保護

若目前 `.env` 已存在，工具不會自動覆蓋。選擇建立或復原時，舊檔會先複製為：

```text
.env.backup_YYYYMMDD_HHMMSS
```

`.gitignore` 已排除 `.env` 與 `.env.*`，避免秘密資料被提交到 GitHub。

## 無法復原舊金鑰時

API Token 無法由空白範本推算。找不到備份時，必須到原服務重新取得或重新產生：

- FinMind：重新取得 `FINMIND_TOKEN`
- Anthropic：重新取得 `ANTHROPIC_API_KEY`
- OpenAI：重新取得 `OPENAI_API_KEY`

不要把實際金鑰貼到 GitHub issue、commit、README 或聊天截圖中。
