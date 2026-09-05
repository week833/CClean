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
1. 取 dataset 宣告的業務欄位白名單，其餘欄位不入 hash；白名單外的欄位是錯誤，不是忽略
2. 數值欄位轉 Decimal，依該欄位宣告小數位以 ROUND_HALF_UP 量化，
   以純小數表示法輸出並去除尾端零；"-0" 折為 "0"
3. 缺值（None、空字串、NaN）統一為空字串，不使用 0、None 或 NaN 的字串形式
4. 依欄位名稱字典序組成 "name=value" 並以 \n 連接
5. UTF-8 編碼後取 sha256 十六進位小寫
```

整數欄位不接受布林值與非整數浮點數，`inf` 一律拒絕。欄位白名單與小數位寫在版本化的
`dataset_spec`，改動即升 `schema_version`。

實作與測試：[`../scripts/dstock_canon/value_hash.py`](../scripts/dstock_canon/value_hash.py)、
[`../scripts/dstock_canon/dataset_spec.py`](../scripts/dstock_canon/dataset_spec.py)。

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
2. **Shadow compare。** 只比兩側都有的非 quarantined `row_key` 的 `value_hash`，算 `match_rate`，寫入 manifest 的 `reconciliation`。
3. **逐 dataset 判定。** 資格是每個 dataset 各自累積，不是整支程式一次通過。

每個交易日、每個 dataset 落在四個帶其中之一：

| 帶 | 條件 | 對 streak | 對 source_class |
|---|---|---|---|
| `qualifying` | `match_rate >= 0.999` 且 `key_only_in_backup = 0` | +1，滿 20 即升為 `backup` | 可升級 |
| `warning` | `0.99 <= match_rate < 0.999` | 歸零 | 維持現狀 |
| `breach` | `match_rate < 0.99`，或 `key_only_in_backup > 0` | 歸零 | 立即降為 `reference_only` |
| `no_evidence` | 當日無重疊 `row_key` | 不變 | 不變 |

`key_only_in_backup > 0` 直接判 breach 而非 warning：primary 沒有產生過的列是幽靈資料，比數值不一致更嚴重。`no_evidence` 不升不降，因為沒有證據不等於證據為負。

分點與估算類（例如融資維持率）本來就不會逐列相等，這類 dataset 不進入 backup 資格，維持 `reference_only`。

實作與測試：[`../scripts/dstock_canon/reconcile.py`](../scripts/dstock_canon/reconcile.py)。

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

### 8.1 這條順序由程式強制，不靠人記得

「ADR 生效前不要讓 backup 替補」如果只是一句約定，遲早會有人忘記。因此它被實作成
[`governance.py`](../scripts/dstock_canon/governance.py) 的閘門：

- **量測與授權分離。** `reconcile` 的資格帳本量測 backup 是否夠接近 primary；`governance`
  記錄治理是否**授權**替補。兩者都成立才放行。這代表 20 日的累積**今天就可以開始跑**，
  不必等 ADR——先有證據，才有值得批准的東西。
- **預設就是拒絕。** 沒有治理宣告時只批准 `primary`，`decide()` 會扣住每一個 backup dataset，
  即使帳本已量測合格、即使呼叫端傳入完整的 `eligible_datasets`。忘記不再是可能的結果之一。
- **拒絕會說明原因。** 決策結果帶 `governance_withheld` 與 `governance_note`，CLI 另印一行
  `[WARN]`，讓操作者讀到的是治理決策而不是疑似故障。只有在拒絕**實際改變結果**時才回報；
  primary 正常的日子不會有雜訊。
- **`reference_only` 永遠不可批准。** 它不是治理選項，宣告檔列入即拒絕載入。
- **壞掉的宣告會擋下，不會放寬。** 檔案不存在等同「尚未批准」（安全的預設）；檔案存在但格式
  錯誤則直接報錯，絕不因為讀不懂而放行。

ADR-0002 採用後，落一份治理宣告（格式見
[`schemas/source_governance.schema.json`](schemas/source_governance.schema.json)）：

```json
{
  "schema": "dstock.market.source_governance",
  "schema_version": 1,
  "ratified_classes": ["primary", "backup"],
  "adr": "ADR-0002",
  "ratified_at": "YYYY-MM-DD"
}
```

以 `--governance <路徑>` 或 `DSTOCK_GOVERNANCE` 環境變數指定。批准 `backup` 必須填
`ratified_at`，作為稽核依據。

## 9. 分階段修改清單

共用實作位於 [`../scripts/dstock_canon/`](../scripts/dstock_canon/)，只用標準函式庫，兩支程式都以
`import dstock_canon` 取用同一份契約。repository 安裝於 `D:\stock\GitHub`，因此 `D:\stock` 下的程式
可將 `D:\stock\GitHub\scripts` 加入 `PYTHONPATH` 後直接匯入。

| 階段 | 內容 | 狀態 |
|---|---|---|
| P0 | `dataset_spec`：join key 順序、欄位白名單、小數位 | 已完成 · `dataset_spec.py` |
| P0 | 兩側各加 `--emit-canonical` 唯讀輸出模式，寫到隔離目錄，不動主流程 | **待本機實作**（呼叫 `build_row`） |
| P1 | `value_hash` 共用函式，兩側匯入同一份實作 | 已完成 · `value_hash.py` |
| P1 | canonical 列建構與 fail-closed 驗證 | 已完成 · `canonical.py` |
| P1 | `market_membership` 與 `trading_calendar` 共用維度表產生器 | **待本機實作**（契約已定義，資料需由本機來源產生） |
| P2 | source receipt 產生與驗證 | 已完成 · `receipt.py` |
| P2 | shadow compare 與資格帳本（20 日累積） | 已完成 · `reconcile.py` |
| P3 | 治理閘門（預設拒絕 backup，宣告後才放行） | 已完成 · `governance.py` |
| P3 | 治理修訂 ADR-0002、`SOURCE_REGISTRY.md`、`dstock-boundary.md` | 草案已備 · [`decisions/ADR-0002-backup-source-class.draft.md`](decisions/ADR-0002-backup-source-class.draft.md)；正式檔在本機 `D:\stock\docs\` |
| P4 | promotion gate 與 central manifest 擴充 | 已完成 · `promotion.py` |
| P5 | 接上 failover 觸發、L2 逐列補洞、restatement 回補 | **待本機實作**（`decide` / `merge_rows` / `plan_restatements` 已可用，排程與觸發需接本機） |
| P6 | 以實機資料跑驗收演練 | **待本機執行**（合成資料的演練已在測試中通過） |

依賴關係：P1 必須在 P2 之前（沒有共用維度表就無法比對），P3 必須在 P4 之前（沒有 ADR 就不能讓 backup 進 gate）。
P3 是治理前提，且已由 `governance.py` 強制（見第 8.1 節）：未落治理宣告前，`decide()` 一律扣住
backup，無論帳本量測結果或呼叫端傳入什麼。因此 P2 的每日雙跑與 20 日累積可以在 ADR 完成前就開始。

### 9.1 命令列

```bash
# 驗證 canonical JSON Lines
python -m dstock_canon validate-rows <rows.jsonl>

# 由 canonical 列產生 receipt
python -m dstock_canon build-receipt --source-id finmind_collect --source-class backup \
  --asof 2026-09-03 --generated-at <ISO8601> --rows daily_price=<rows.jsonl> \
  --expected daily_price=1043 --code-version <ver> --config-hash <hash> -o <receipt.json>

# 每日 shadow compare 並累積資格
python -m dstock_canon compare --trading-day 2026-09-03 \
  --primary daily_price=<primary.jsonl> --backup daily_price=<backup.jsonl> --ledger <ledger.json>

# promotion gate 與 central manifest
# 省略 --governance 時只批准 primary（ADR-0002 前的狀態），backup 一律扣住。
python -m dstock_canon promote --required daily_price \
  --primary-receipt <p.json> --backup-receipt <b.json> --ledger <ledger.json> \
  [--governance <governance.json>] \
  --asof 2026-09-03 --generated-at <ISO8601> -o <manifest.json>
```

機器可讀結果走 stdout，人類訊息走 stderr，因此可直接把 stdout 接進 JSON parser 而不需要合併 stderr。
`promote` 在 `L3` 時回傳 exit code 3（阻擋，不是錯誤），輸入本身有問題時回傳 2。

### 9.2 `--emit-canonical` 的接法

兩側的輸出模式都只是把既有查詢結果逐列丟給 `build_row`，不改各自的取得邏輯。
下面是形狀示範，不是可直接複製的實作：每個判斷點都必須由該程式自己的證據決定，
不可為了讓列通過而填入猜測值。

```python
import os, sys
sys.path.insert(0, os.path.join(os.environ["STOCK_HOME"], "scripts"))

from dstock_canon import build_row, write_rows

def to_canonical(source_rows, *, source_id, source_class, asof, ingested_at):
    for raw in source_rows:
        stock_id = raw["stock_id"]

        # 三個判斷點都必須有證據，沒有證據就填 unknown，讓契約自己隔離該列。
        # 不要為了讓列通過而猜測。
        market = market_membership_as_of(stock_id, raw["date"])       # 無證據 -> "unknown"
        unit_basis = declared_volume_unit(source_id, market)          # 無證據 -> "unknown"
        availability_time, basis = availability_evidence(raw)         # 無證據 -> (None, "unknown")

        yield build_row(
            dataset="daily_price",
            key_values={"stock_id": stock_id, "date": raw["date"]},
            values={
                "open": raw["open"], "high": raw["max"], "low": raw["min"],
                "close": raw["close"], "change": raw["spread"],
                "volume_shares": to_shares(raw["Trading_Volume"], unit_basis),
                "turnover_value": raw["Trading_money"],
                "transaction_count": raw["Trading_turnover"],
                "limit_up": None, "limit_down": None,
            },
            row_date=raw["date"],
            source_id=source_id, source_class=source_class,
            ingested_at=ingested_at,
            availability_basis=basis, availability_time=availability_time,
            market=market, unit_basis=unit_basis, price_basis="raw",
        )

write_rows(out_path, to_canonical(...))
```

三件事要特別注意：

1. **`to_shares()` 在 `unit_basis` 為 `unknown` 時必須原樣回傳，不可換算。** 契約會把該列隔離；
   若先猜著換算再交給契約，隔離就失去意義。
2. **`limit_up` / `limit_down` 沒取到就填 `None`，不要填 0。** 0 在漲跌停欄位是「無漲跌幅限制」的
   合法值（部分槓桿／反向 ETF、興櫃），與缺值不同；`value_hash` 也把兩者視為不同。
3. **`price_basis="adjusted"` 一定要帶 `adj_snapshot_id`。** 還原價會被截止日後的事件回溯改寫，
   沒有凍結 snapshot 就無法產生穩定 hash，兩側也就永遠比不相等。

在 ADR-0002 生效前，這個模式產生的檔案只能寫進隔離目錄，並以空的 `eligible_datasets`
呼叫 `decide()`。

## 10. 驗收演練

四個必跑情境，缺一不可：

1. **斷 primary 一天** → manifest 應為 `L1`／`degraded`，報告仍產出且標示降級。
2. **斷 backup** → manifest 應維持 `L0`，完全不受影響。
3. **兩者皆斷** → 應為 `L3`／`blocked`，不得產出空資料或沿用前一日。
4. **注入錯誤 backup 資料**（單位錯、缺三天、混入未來列）→ conformance 必須擋下並降級該 dataset，不得通過。

第 4 項是重點：能擋下錯誤資料，才代表這套互補是安全的，而不只是「兩邊都有資料」。

這四個情境已用合成資料寫成測試，見
[`../scripts/dstock_canon/tests/test_promotion.py`](../scripts/dstock_canon/tests/test_promotion.py)
的 `AcceptanceDrillTests`。合成資料通過不等於實機通過：P6 仍必須以真實 `shared_market_data` 與真實
collect 輸出重跑一次，因為合成資料無法呈現實際的單位、市場別與缺日分布。

執行全部契約測試：

```cmd
RUN_CANON_TESTS.cmd
```

CI 於 `ubuntu-latest` 與 `windows-latest`、Python 3.10 與 3.12 上執行相同測試，並額外檢查
`docs/schemas/` 的 JSON schema 與 `scripts/dstock_canon/` 的實作沒有分歧
（[`check_schema_parity.py`](../scripts/dstock_canon/tests/check_schema_parity.py)）。
兩份契約表述若不一致，CI 會擋下。

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
