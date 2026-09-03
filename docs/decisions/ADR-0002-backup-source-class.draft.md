# ADR-0002（草案）：新增 backup source class 與降級分級

> **這是草案，不是已生效的治理決策。** D-stock 的正式 ADR 位於 `D:\stock\docs\decisions\`，不在本 repository。
> 採用前請將本檔調整為與 `ADR-0001-ai-core-four-assets.md` 相同的格式與編號慣例，放入該目錄，
> 並同步更新 `D:\stock\docs\SOURCE_REGISTRY.md`。在該步驟完成前，本 repository 的
> `scripts/dstock_canon` 只能以空的 `eligible_datasets` 呼叫，輸出僅落在隔離目錄。

- 狀態：草案
- 日期：2026-09-03
- 取代：無
- 相關：`ADR-0001-ai-core-four-assets.md`、[`../data_source_failover_plan.md`](../data_source_failover_plan.md)

## 背景

現行來源分類只有兩級：

- `primary`：中央 `market_update`，是 `D:\TWStockData\shared_market_data` 的 system of record。
- `reference-only`：外部 GitHub repository、FinMind API 查詢、三竹可見 UI 觀察。依現行治理，
  這一級不會、也不應自動成為正式行情、正式模型輸入或正式報告的來源。

這個二元分類在單一情境下失效：**當 `market_update` 當日失效時，沒有任何合規路徑可以補上資料。**
結果是整天的正式報告 fail-closed，即使另一支程式當天確實取得了同樣的資料。反向亦然，
collect 側失效時沒有機制記錄「今天沒有第二來源可交叉驗證」。

單純把 collect 側改判為 `primary` 不可行：它缺少可得時間證據、缺少以交易日曆推得的覆蓋分母、
其還原價格會被截止日後的事件回溯改寫，且單位與市場別在缺乏 as-of membership 證據時無法確認。
把這些不確定性直接放進正式資料，比缺一天資料更危險。

## 決策

新增第三級 `backup`，並以降級分級表達「用了替補來源」這件事，而不是讓它偽裝成正常資料。

### 1. source class 三級

| class | 意義 | 可否進 promotion gate |
|---|---|---|
| `primary` | 中央 `market_update` | 可，且是唯一能產生 `publishable` 的來源 |
| `backup` | 已通過 conformance 的 collect 來源，逐 dataset 認定 | 可，但最高只到 `degraded` |
| `reference_only` | 未通過或不適用 conformance 的來源 | 否，永遠不參與替補與合併 |

`backup` 是**逐 dataset** 的資格，不是整支程式的身分。同一支 collect 程式可以在 `daily_price`
上是 `backup`，同時在 `broker_branch` 上是 `reference_only`。

### 2. 資格以連續實測取得

兩側每個交易日都跑，對雙方都有的非 quarantined `row_key` 比對 `value_hash`：

| 帶 | 條件 | 效果 |
|---|---|---|
| `qualifying` | `match_rate >= 0.999` 且 `key_only_in_backup = 0` | streak +1，連續 20 個交易日後升為 `backup` |
| `warning` | `0.99 <= match_rate < 0.999` | streak 歸零，維持現有 class |
| `breach` | `match_rate < 0.99`，或出現 backup 才有的列 | 立即降為 `reference_only`，streak 歸零 |
| `no_evidence` | 當日無重疊 `row_key` | 不升不降 |

資格不可由宣告、文件或人工判斷取得，只能由帳本累積。分點與估算類資料集
（例如融資維持率）本質上不會逐列相等，不進入此流程，永久維持 `reference_only`。

### 3. 降級分級

| 等級 | 條件 | publishability |
|---|---|---|
| `L0` | primary 覆蓋全部所需 dataset 且 PIT 乾淨 | `publishable` |
| `L1` | primary 完全未覆蓋，合格 backup 全量替補 | `degraded` |
| `L2` | primary 覆蓋一部分，合格 backup 補其餘 | `degraded` |
| `L3` | 兩者聯集仍有缺口 | `blocked` |

`degraded` 不是「比較差的通過」，而是一個必須向下游揭露的事實：報告可產出但必須標示；
要進正式模型需另外核准。`blocked` 維持既有 fail-closed 行為，不得產出空資料或沿用前一日。

### 4. 邊界

- collect 側**不得**直接寫入 `shared_market_data`。兩側都只輸出 canonical 列與 receipt，
  由單一 promotion gate 決定。
- `reference_only` 的列永不進入合併，即使當日沒有其他來源。
- primary 復原後以 primary 覆蓋 backup 列，但舊列保留於歷史並記入 `restatements`；
  不刪除、不靜默覆蓋。
- 本 ADR 不改變任何資料的授權範圍。把外部來源資料落地保存為 backup 屬於資料保存行為，
  必須另行核對該來源當期使用條款與原始資料機關授權。

## 後果

**取得**

- `market_update` 單日失效不再必然導致整天報告中斷。
- 「兩側資料是否一致」從主觀判斷變成每日可量測的數字，並留下帳本。
- 降級狀態顯式寫入 manifest，下游可以自行決定接受或拒絕。

**付出**

- 兩側必須每天都跑，即使 primary 正常，成本與配額消耗增加。
- 新增需要維護的狀態：資格帳本、canonical 列、第二份 receipt。
- 新的誤用風險：若有人把 `degraded` 當成 `publishable` 使用，等於繞過本 ADR 的保護。
  下游消費端必須明確處理 `degradation_level`，不可只看資料是否存在。

**未解決**

- backup 落地保存的授權範圍尚未逐 dataset 確認。
- 20 個交易日與 0.999／0.99 三個門檻是初始值，需以實際對帳分布回頭校準。
- 三竹可見 UI 來源不在本 ADR 的升級路徑內；其 `direct_prediction_weight` 維持 0。
