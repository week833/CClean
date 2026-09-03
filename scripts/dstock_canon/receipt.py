"""Source receipt construction and validation.

Both sources emit the same receipt shape so the promotion gate can judge them
with one rule set. A receipt is derived from rows, never hand-written: the
counts, coverage and rollup hash are computed here so that a source cannot
claim eligibility it has not demonstrated.
"""

from __future__ import annotations

import json
from collections import Counter
from datetime import date
from typing import Any, Iterable, Mapping, Sequence

from .canonical import CanonicalError, validate_row
from .dataset_spec import SOURCE_CLASSES, SOURCE_IDS, get_spec
from .value_hash import rollup_hash

SCHEMA_NAME = "dstock.market.source_receipt"
SCHEMA_VERSION = 1

STATUSES = ("complete", "partial", "failed")
PUBLISHABILITIES = ("publishable", "degraded", "blocked")
FAILURE_REASONS = (
    "source_unreachable",
    "quota_exceeded",
    "auth_failed",
    "schema_mismatch",
    "coverage_below_threshold",
    "stale_asof",
    "internal_error",
)

_RECEIPT_FIELDS = (
    "schema", "schema_version", "source_id", "source_class", "asof", "expected_asof",
    "generated_at", "status", "publishability", "datasets", "pit", "evidence", "failure",
)
_DATASET_FIELDS = (
    "dataset", "expected_rows", "actual_rows", "missing_rows", "future_row_count",
    "quarantined_rows", "coverage_to_cutoff", "value_hash", "availability_basis_counts",
    "quality_flag_counts",
)


class ReceiptError(ValueError):
    """Raised when a receipt violates the shared contract."""


def _iso(value: Any, label: str) -> date:
    if not isinstance(value, str):
        raise ReceiptError(f"{label} 必須是 YYYY-MM-DD 字串")
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise ReceiptError(f"{label} 不是合法日期: {value!r}") from None


def summarize_dataset(
    dataset: str,
    rows: Sequence[Mapping[str, Any]],
    *,
    expected_rows: int,
    asof: str,
) -> dict[str, Any]:
    """Derive one dataset block from its rows. Rows must already be validated."""
    get_spec(dataset)
    cutoff = _iso(asof, "asof")
    if expected_rows < 0:
        raise ReceiptError(f"{dataset} 的 expected_rows 不可為負")

    seen: set[str] = set()
    usable: dict[str, str] = {}
    future = 0
    quarantined = 0
    basis: Counter[str] = Counter()
    flags: Counter[str] = Counter()

    for row in rows:
        if row["dataset"] != dataset:
            raise ReceiptError(f"{dataset} 的列集合混入 {row['dataset']}")
        key = row["row_key"]
        if key in seen:
            raise ReceiptError(f"{dataset} 出現重複 row_key: {key}")
        seen.add(key)
        basis[row["availability_basis"]] += 1
        flags.update(row["quality_flags"])
        if row["quarantined"]:
            quarantined += 1
        if date.fromisoformat(row["row_date"]) > cutoff:
            future += 1
            continue
        if not row["quarantined"]:
            usable[key] = row["value_hash"]

    usable_count = len(usable)
    if expected_rows == 0:
        if usable_count:
            raise ReceiptError(f"{dataset} 的預期分母為 0 但有 {usable_count} 筆可用列；分母不可由實際列數回填")
        coverage = 1.0
    else:
        coverage = min(usable_count / expected_rows, 1.0)

    return {
        "dataset": dataset,
        "expected_rows": expected_rows,
        "actual_rows": len(rows),
        "missing_rows": max(expected_rows - usable_count, 0),
        "future_row_count": future,
        "quarantined_rows": quarantined,
        "coverage_to_cutoff": coverage,
        "value_hash": rollup_hash(usable),
        "availability_basis_counts": dict(sorted(basis.items())),
        "quality_flag_counts": dict(sorted(flags.items())),
    }


def _publishability(source_class: str, status: str, future: int, unknown: int) -> str:
    if status == "failed" or future or unknown:
        return "blocked"
    if source_class == "reference_only":
        return "blocked"
    if status != "complete":
        return "degraded"
    return "publishable" if source_class == "primary" else "degraded"


def build_receipt(
    *,
    source_id: str,
    source_class: str,
    asof: str,
    expected_asof: str,
    generated_at: str,
    rows_by_dataset: Mapping[str, Sequence[Mapping[str, Any]]],
    expected_rows: Mapping[str, int],
    research_cutoff: str | None = None,
    evidence: Mapping[str, Any],
    conservative_lag_policy: Mapping[str, str] | None = None,
) -> dict[str, Any]:
    """Derive a receipt from validated rows."""
    if not rows_by_dataset:
        raise ReceiptError("receipt 至少要有一個 dataset；完全沒有資料請用 failed_receipt")
    missing_expected = sorted(set(rows_by_dataset) - set(expected_rows))
    if missing_expected:
        raise ReceiptError(f"缺少預期分母的 dataset: {missing_expected}")

    blocks = []
    for dataset in sorted(rows_by_dataset):
        rows = rows_by_dataset[dataset]
        for row in rows:
            validate_row(row)
            if row["source_id"] != source_id or row["source_class"] != source_class:
                raise ReceiptError(f"{dataset} 的列來源與 receipt 不符: {row['row_key']}")
        blocks.append(summarize_dataset(dataset, rows, expected_rows=expected_rows[dataset], asof=asof))

    all_rows = [row for rows in rows_by_dataset.values() for row in rows]
    future_total = sum(block["future_row_count"] for block in blocks)
    unknown_total = sum(1 for row in all_rows if row["availability_basis"] == "unknown")
    lag_total = sum(1 for row in all_rows if row["availability_basis"] == "conservative_lag")

    complete = all(block["coverage_to_cutoff"] >= 1.0 for block in blocks) and future_total == 0
    status = "complete" if complete else "partial"

    receipt = {
        "schema": SCHEMA_NAME,
        "schema_version": SCHEMA_VERSION,
        "source_id": source_id,
        "source_class": source_class,
        "asof": asof,
        "expected_asof": expected_asof,
        "generated_at": generated_at,
        "status": status,
        "publishability": _publishability(source_class, status, future_total, unknown_total),
        "datasets": blocks,
        "pit": {
            "research_cutoff": research_cutoff or asof,
            "future_row_count": future_total,
            "unknown_availability_rows": unknown_total,
            "conservative_lag_rows": lag_total,
            "conservative_lag_policy": dict(conservative_lag_policy or {}),
        },
        "evidence": dict(evidence),
        "failure": None,
    }
    validate_receipt(receipt)
    return receipt


def failed_receipt(
    *,
    source_id: str,
    source_class: str,
    asof: str,
    expected_asof: str,
    generated_at: str,
    reason_code: str,
    detail: str,
    evidence: Mapping[str, Any],
) -> dict[str, Any]:
    """Build the receipt a source must still emit when it could not collect."""
    if reason_code not in FAILURE_REASONS:
        raise ReceiptError(f"未註冊的 reason_code: {reason_code}")
    receipt = {
        "schema": SCHEMA_NAME,
        "schema_version": SCHEMA_VERSION,
        "source_id": source_id,
        "source_class": source_class,
        "asof": asof,
        "expected_asof": expected_asof,
        "generated_at": generated_at,
        "status": "failed",
        "publishability": "blocked",
        "datasets": [],
        "pit": {
            "research_cutoff": asof,
            "future_row_count": 0,
            "unknown_availability_rows": 0,
            "conservative_lag_rows": 0,
            "conservative_lag_policy": {},
        },
        "evidence": dict(evidence),
        "failure": {"reason_code": reason_code, "detail": detail},
    }
    validate_receipt(receipt)
    return receipt


def validate_receipt(receipt: Mapping[str, Any]) -> None:
    """Raise ReceiptError unless the receipt satisfies the shared contract."""
    if not isinstance(receipt, Mapping):
        raise ReceiptError("receipt 必須是物件")
    unknown = set(receipt) - set(_RECEIPT_FIELDS)
    if unknown:
        raise ReceiptError(f"receipt 含不允許欄位: {sorted(unknown)}")
    missing = [name for name in _RECEIPT_FIELDS if name not in receipt]
    if missing:
        raise ReceiptError(f"receipt 缺少欄位: {missing}")

    if receipt["schema"] != SCHEMA_NAME:
        raise ReceiptError(f"schema 必須是 {SCHEMA_NAME}")
    if receipt["schema_version"] != SCHEMA_VERSION:
        raise ReceiptError(f"schema_version 必須是 {SCHEMA_VERSION}")
    if receipt["source_id"] not in SOURCE_IDS:
        raise ReceiptError(f"未註冊的 source_id: {receipt['source_id']!r}")
    if receipt["source_class"] not in SOURCE_CLASSES:
        raise ReceiptError(f"未註冊的 source_class: {receipt['source_class']!r}")
    if receipt["status"] not in STATUSES:
        raise ReceiptError(f"未註冊的 status: {receipt['status']!r}")
    if receipt["publishability"] not in PUBLISHABILITIES:
        raise ReceiptError(f"未註冊的 publishability: {receipt['publishability']!r}")

    asof = _iso(receipt["asof"], "asof")
    expected_asof = _iso(receipt["expected_asof"], "expected_asof")

    pit = receipt["pit"]
    if not isinstance(pit, Mapping):
        raise ReceiptError("pit 必須是物件")
    for name in ("research_cutoff", "future_row_count", "unknown_availability_rows"):
        if name not in pit:
            raise ReceiptError(f"pit 缺少 {name}")
    _iso(pit["research_cutoff"], "pit.research_cutoff")

    datasets = receipt["datasets"]
    if not isinstance(datasets, list):
        raise ReceiptError("datasets 必須是陣列")
    seen: set[str] = set()
    for block in datasets:
        unknown_block = set(block) - set(_DATASET_FIELDS)
        if unknown_block:
            raise ReceiptError(f"dataset 區塊含不允許欄位: {sorted(unknown_block)}")
        for name in _DATASET_FIELDS[:-1]:
            if name not in block:
                raise ReceiptError(f"dataset 區塊缺少 {name}")
        get_spec(block["dataset"])
        if block["dataset"] in seen:
            raise ReceiptError(f"dataset 重複出現: {block['dataset']}")
        seen.add(block["dataset"])
        if not 0.0 <= block["coverage_to_cutoff"] <= 1.0:
            raise ReceiptError(f"{block['dataset']} 的 coverage_to_cutoff 必須落在 0 與 1 之間")
        if len(block["value_hash"]) != 64:
            raise ReceiptError(f"{block['dataset']} 的 value_hash 必須是 sha256 十六進位")

    if receipt["status"] == "failed":
        if receipt["publishability"] != "blocked":
            raise ReceiptError("status=failed 時 publishability 必須是 blocked")
        if not receipt.get("failure"):
            raise ReceiptError("status=failed 必須附上 failure 區塊")
        if receipt["failure"].get("reason_code") not in FAILURE_REASONS:
            raise ReceiptError("failure.reason_code 未註冊")
    elif not datasets:
        raise ReceiptError("非 failed 的 receipt 必須至少有一個 dataset")

    if receipt["publishability"] == "publishable":
        if receipt["status"] != "complete":
            raise ReceiptError("publishable 需要 status=complete")
        if pit["future_row_count"] or pit["unknown_availability_rows"]:
            raise ReceiptError("publishable 不可有未來列或未知可得時間列")
        if receipt["source_class"] != "primary":
            raise ReceiptError("只有 primary 來源的 receipt 可為 publishable")

    if asof > expected_asof:
        raise ReceiptError("asof 不可晚於 expected_asof")

    evidence = receipt["evidence"]
    if not isinstance(evidence, Mapping):
        raise ReceiptError("evidence 必須是物件")
    for name in ("code_version", "config_hash"):
        if not evidence.get(name):
            raise ReceiptError(f"evidence 缺少 {name}")


def is_stale(receipt: Mapping[str, Any]) -> bool:
    """True when the receipt's asof lags the trading calendar's expected asof."""
    return _iso(receipt["asof"], "asof") < _iso(receipt["expected_asof"], "expected_asof")


def read_receipt(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        receipt = json.load(handle)
    validate_receipt(receipt)
    return receipt


def write_receipt(path: str, receipt: Mapping[str, Any]) -> None:
    validate_receipt(receipt)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(receipt, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
