# 雙來源互補修改計劃：collect tool 與中央資料

本文件是 data collect tool 與中央 `market_update` 兩支程式的互通與互補修改計劃。目標是讓兩者輸出同一份契約，任一支失效時另一支可以補資料，且補進來的資料仍然可被稽核、可被拒絕，不會靜默升格成正式資料。

本文件只定義契約與修改步驟，不修改中央資料、不改既有 receipt，也不授權任何繞過既有入口的行為。

## 1. 現況與阻擋點

現行治理把兩側綁在不同的 source class，因此「直接互通」在契約上就不成立：

| 項目 | 現況 | 依據 |
|---|---|---|
| 正式共用原始資料 | `D:\TWStockData\shared_market_data` | `finmind-twstock-research-skill` 的 `references/dstock-boundary.md` |
| 資料資格判定 | 中央 receipt `latest_manifest.json` 的 status、publishability、expected_asof、coverage、PIT、hash | 同上 |
| FinMind 查詢 | `reference-only`，不會自動成為 system of record | 同上 |
| 三竹可見 UI adapter | `supplementary_watchlist_evidence_only`、`watchlist_evidence_only`、`blocked_until_point_in_time_backtest` | `docs/mitake/capabilities.json` 的 `existing_adapter_coverage` |
| `shared_data_paths.json` | 只定義 routing，不是資料內容或 freshness 證據 | `dstock-boundary.md` |

技術面另有四個結構性缺料，就算檔案格式接上也會被 receipt gate 擋下：

1. **可得時間缺失**。資料列的 `date` 多半是交易日或報告期間，不是可取得時間；沒有公告／建立證據時 PIT 為 `unknown`。
2. **hash 不穩定**。還原價格會被截止日之後的事件回溯改寫，重抓的歷史與舊值不同，無法產生穩定 hash。
3. **coverage 分母缺失**。collect 側普遍只有實際列數，沒有以交易日曆推得的預期分母。
4. **單位與市場別不確定**。上市櫃以張、興櫃以股；沒有 as-of market membership 證據時不得換算。

## 2. 目標架構

不採用「collect 直接寫入 `shared_market_data`」。改為兩側各自輸出 canonical 列與同格式 receipt，交給單一 promotion gate 判定：

```text
market_update ──┐
                ├─► canonical rows + source receipt ─► promotion gate ─► shared_market_data
collect tool ───┘                                          │
                                                           └─► central manifest
                                                               (sources[] / effective_source / degradation_level)
```

三個設計決定：

- **契約在列層，不在檔案層。** 互補的單位是「一列」，不是「一個檔」，才能做到部分補洞。
- **promotion gate 只有一個。** 兩側都不能自己決定自己是正式資料。
- **降級要顯式。** 補上來的資料標 `degraded`，下游可以選擇接受或拒絕，不是二選一的通過或失敗。

## 3. Canonical 契約

規格見 [`schemas/canonical_row.schema.json`](schemas/canonical_row.schema.json)。每一列除業務欄位外強制帶下列封套：

| 欄位 | 作用 |
|---|---|
| `dataset` / `row_key` | 兩側必須用同一 logical table 名稱與同一 join key 順序 |
| `row_date` | 資料日，與可得時間分離 |
| `availability_time` / `availability_basis` | 可得時間與其依據；`conservative_lag` 表示以保守延遲推得 |
| `source_id` / `source_class` | 逐列來源標記，混合補洞後仍可回溯 |
| `market` / `unit_basis` | as-of 市場別與原始成交量單位 |
| `price_basis` / `adj_snapshot_id` | raw 與 adjusted 強制分離，adjusted 必須綁定凍結 snapshot |
| `value_hash` | 業務欄位正規化後的 sha256，跨來源逐列比對的唯一依據 |
| `quarantined` | 保留為證據但不得進入正式 join、特徵或報告 |

schema 已內建三條 fail-closed 規則：`availability_basis`、`unit_basis` 或 `market` 為 `unknown` 時，`quarantined` 必須為 `true`。

### 3.1 join key 固定順序

| dataset | row_key 組成 |
|---|---|
| `daily_price` | `stock_id \| date` |
| `institutional_investors` | `stock_id \| date \| investor_name` |
| `broker_branch` | `stock_id \| date \| securities_trader_id` |
| `margin_short_sale` | `stock_id \| date` |
| `shareholding` | `stock_id \| date` |
| `month_revenue` | `stock_id \| revenue_year \| revenue_month` |
| `financial_statements` | `stock_id \| date \| type` |
| `dividend_event` | `stock_id \| event_type \| event_date` |
| `trading_calendar` | `market \| date` |
| `market_membership` | `stock_id \| valid_from` |

### 3.2 三個必須共用的正規化規則

- **單位一律轉股。** `values` 內成交量存 shares，`unit_basis` 保留原始語意。無 as-of membership 證據時 `unit_basis=unknown`、不換算、標 `quarantined` 與 `unit_unconvertible`。
- **`market_membership` 是共用維度表。** key 為 `(stock_id, valid_from, valid_to, market)`。兩側都從這張表取 as-of 市場別，不各自用最新一列回推歷史。
- **adjusted 只存凍結 snapshot。** 每次重算產生新的 `adj_snapshot_id` 與新 hash，不覆蓋既有 snapshot。raw 與 adjusted 不得混入同一價格序列。

### 3.3 value_hash 計算

兩側必須用同一演算法，否則比對永遠不相等：

```text
1. 取 dataset 宣告的業務欄位白名單，其餘欄位不入 hash
2. 數值欄位轉 Decimal，依該欄位宣告小數位四捨五入，去除尾端零
3. 缺值統一為空字串，不使用 0、None 或 NaN 的字串形式
4. 依欄位名稱字典序組成 "name=value" 並以 \n 連接
5. UTF-8 編碼後取 sha256 十六進位小寫
```

欄位白名單與小數位必須寫在版本化的 `dataset_spec`，改動即升 `schema_version`。

## 4. Receipt 與降級分級

規格見 [`schemas/source_receipt.schema.json`](schemas/source_receipt.schema.json) 與 [`schemas/central_manifest.schema.json`](schemas/central_manifest.schema.json)。

兩側每個 asof 各產生一份 source receipt，形狀完全相同；中央 manifest 以 `sources[]` 收攏，並記錄 `effective_source` 與 `degradation_level`。

| 等級 | 條件 | publishability | 下游規則 |
|---|---|---|---|
| `L0` | primary 完整且通過 PIT gate | `publishable` | 正式可用 |
| `L1` | primary 失效，backup 全量替補且通過 conformance 與 PIT gate | `degraded` | 報告可用並標示；進正式模型需另外核准 |
| `L2` | primary 部分覆蓋，backup 只補缺口列 | `degraded` | 同 L1，且逐列 `source_id` 必須保留 |
| `L3` | 兩側皆失敗，或 backup 未通過 conformance | `blocked` | fail-closed，不產出正式報告 |

`publishable` 的硬條件（已寫入 receipt schema）：`status=complete`、`pit.future_row_count=0`、`pit.unknown_availability_rows=0`。

## 5. 如何證明兩側「相同」

不靠宣稱，靠連續實測。這是 backup 取得資格的唯一途徑：

1. **每天雙跑。** 即使 primary 正常也要跑 backup，兩份 receipt 都留。
2. **Shadow compare。** 對兩側都有的 `row_key` 比 `value_hash`，算 `match_rate`，寫入 manifest 的 `reconciliation`。
3. **升級門檻。** 某個 dataset 連續 20 個交易日 `match_rate >= 0.999` 且 `key_only_in_backup = 0`，該 dataset 的 backup 才可從 `reference_only` 升為 `backup`。
4. **降級門檻。** 任一交易日 `match_rate < 0.99`，該 dataset 立即降回 `reference_only`，需重新累積 20 日。
5. **逐 dataset 判定。** 資格是每個 dataset 各自累積，不是整支程式一次通過。

`match_rate` 門檻依 dataset 分開設定；分點與估算類（例如融資維持率）本來就不會逐列相等，這類 dataset 不進入 backup 資格，維持 `reference_only`。

## 6. Precedence 與衝突處理

同一 `row_key` 出現多來源時，依序判定：

1. `source_class` 較高者優先（`primary` > `backup`，`reference_only` 永不參與）
2. 同 class 比 `availability_basis` 品質：`announced` > `created` > `vendor_publish` > `conservative_lag`
3. 再同則取 `ingested_at` 較早者，避免每日重跑造成抖動
4. 值不一致且都是 `primary` → 記入 manifest `conflicts`，該列 `quarantined`，不自動挑一個

## 7. Failover 觸發、補資料與回補

**觸發條件**（可測、不靠人判斷）：

- primary receipt 在 `expected_asof + T` 仍非 `complete`（建議 T = 90 分鐘，寫在設定不寫死）
- 或 primary receipt 檔案不存在、無法解析、hash 不符
- 或某 dataset 的 `coverage_to_cutoff` 低於該 dataset 門檻

**觸發後**：backup 針對同一 `asof` 執行，產生 receipt，走同一 promotion gate。只補資格已為 `backup` 的 dataset；其餘 dataset 維持缺口並讓 manifest 進 `L3`，不以部分資料假裝完整。

**回補與更正**：primary 恢復後對同一 `asof` 重跑並產生 primary receipt。

- 值一致 → 只更新 `effective_source`，`degradation_level` 由 L1／L2 回到 L0
- 值不一致 → 以 primary 覆蓋，backup 舊列保留於歷史，並寫一筆 `restatements`
- 絕不刪除 backup 列，絕不靜默覆蓋，絕不因為「現在有資料了」就把既往的 degraded 標記抹掉

## 8. 治理修訂（必須先做，否則後面都是違規）

現行 ADR 與 `SOURCE_REGISTRY.md` 只有 `primary` 與 `reference-only` 兩級，沒有 `backup`。修改順序：

1. 新增 `ADR-0002`：定義 `backup` source class、conformance 與升降級門檻、L0–L3 分級、degraded 資料的下游使用規則。
2. 更新 `SOURCE_REGISTRY.md`：collect tool 由 `reference-only` 改為 `backup (conditional)`，並註明逐 dataset 資格。
3. 更新 `dstock-boundary.md` 分流表：新增 backup 列，說明 backup 補資料仍不等於正式驗收。
4. 更新 `shared_data_paths.json`：新增 backup 落地與 receipt 路徑，仍僅為 routing。

未完成第 1、2 項之前，第 9 節的程式修改只能輸出到隔離目錄，不得進入 promotion gate。

## 9. 分階段修改清單

| 階段 | 內容 | 產出 |
|---|---|---|
| P0 | 兩側各加 `--emit-canonical` 唯讀輸出模式，寫到隔離目錄，不動主流程 | 兩份 canonical 檔 |
| P0 | 建立 `dataset_spec`（欄位白名單、小數位、join key 順序） | 版本化設定 |
| P1 | 建立 `market_membership` 與 `trading_calendar` 共用維度表產生器 | 兩張 as-of 表 |
| P1 | 實作 `value_hash` 共用函式，兩側匯入同一份實作，不各寫一份 | 共用模組 |
| P2 | 兩側輸出 source receipt；實作 schema 驗證器 | receipt + validator |
| P2 | 實作 shadow compare 與 `reconciliation` 統計，開始累積 20 日資格 | 每日對帳報告 |
| P3 | 治理修訂 ADR-0002、`SOURCE_REGISTRY.md`、`dstock-boundary.md` | 文件 |
| P4 | 實作 promotion gate 與 central manifest 擴充（`sources[]` / `effective_source` / `degradation_level`） | manifest v1 |
| P5 | 接上 failover 觸發、L2 逐列補洞、restatement 回補 | 可運作的互補 |
| P6 | 驗收演練 | 演練紀錄 |

依賴關係：P1 必須在 P2 之前（沒有共用維度表就無法比對），P3 必須在 P4 之前（沒有 ADR 就不能讓 backup 進 gate）。

## 10. 驗收演練

四個必跑情境，缺一不可：

1. **斷 primary 一天** → manifest 應為 `L1`／`degraded`，報告仍產出且標示降級。
2. **斷 backup** → manifest 應維持 `L0`，完全不受影響。
3. **兩者皆斷** → 應為 `L3`／`blocked`，不得產出空資料或沿用前一日。
4. **注入錯誤 backup 資料**（單位錯、缺三天、混入未來列）→ conformance 必須擋下並降級該 dataset，不得通過。

第 4 項是重點：能擋下錯誤資料，才代表這套互補是安全的，而不只是「兩邊都有資料」。

## 11. 明確不做的事

- 不讓 collect tool 直接寫入 `shared_market_data`。
- 不修改既有 receipt 的既有欄位語意，只新增欄位。
- 不把 `reference_only` 的 dataset 拿來補資料。
- 不以「有資料」取代 receipt 判定；缺 PIT、coverage 或 hash 一律 fail-closed。
- 不在 receipt、canonical 列或對帳報告寫入 token、憑證、signed URL 或完整 API 回應。
- 不把三竹可見 UI 的畫面內容當成行情資料來源；其 `direct_prediction_weight` 維持 0。

## 12. 待確認事項

下列項目本文件無法從 repository 證實，實作前必須在本機核對：

- `shared_market_data` 的實際目錄結構、分區方式與檔案格式。
- 現行 `latest_manifest.json` 的實際欄位，以確認第 4 節為純新增而非改寫。
- data collect tool 的實際進入點與現有輸出格式。
- 中央 `market_update` 的排程時間，以決定第 7 節的 `T`。
- 各 dataset 的授權範圍，特別是可否把外部來源資料落地保存為 backup。

## 13. 依據

- `docs/mitake/README.md`、`docs/mitake/capabilities.json`
- `week833/finmind-twstock-research-skill` 的 `references/dstock-boundary.md`、`references/pit-quality.md`、`references/research-recipes.md`、`references/dataset-routing.md`
- 本機治理檔（未在本 repository）：`D:\stock\docs\HANDOFF.md`、`D:\stock\docs\SOURCE_REGISTRY.md`、`D:\stock\docs\decisions\ADR-0001-ai-core-four-assets.md`
