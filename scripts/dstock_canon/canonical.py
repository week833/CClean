"""Canonical row construction and fail-closed validation.

A canonical row is the unit of interoperability: both sources emit the same
envelope for the same logical fact, so a failover can substitute rows one at a
time instead of whole files.

The fail-closed rules enforced here mirror docs/schemas/canonical_row.schema.json
and are deliberately stricter in one place: validate_row recomputes value_hash
from the values, so a row cannot claim a hash it does not have.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Iterable, Iterator, Mapping

from .dataset_spec import (
    AVAILABILITY_BASES,
    KEY_SEPARATOR,
    MARKETS,
    PRICE_BASES,
    SCHEMA_NAME,
    SCHEMA_VERSION,
    SOURCE_CLASSES,
    SOURCE_IDS,
    UNIT_BASES,
    DatasetSpec,
    SpecError,
    get_spec,
)
from .value_hash import value_hash

QUALITY_FLAGS = frozenset({
    "zero_price_no_published_trade",
    "emerging_open_is_prev_avg",
    "broker_price_zero_with_volume",
    "limit_absent_not_null",
    "estimated_value",
    "stale_snapshot",
    "duplicate_key",
    "unit_unconvertible",
    "schema_unknown",
})

# Envelope values that force quarantine. Keeping the reason with the trigger
# means a caller can explain why a row was held back.
_QUARANTINE_TRIGGERS = (
    ("availability_basis", "unknown", "無可得時間證據"),
    ("unit_basis", "unknown", "成交量單位無法確認"),
    ("market", "unknown", "無 as-of 市場別證據"),
)

_ROW_FIELDS = (
    "schema", "schema_version", "dataset", "row_key", "row_date", "availability_time",
    "availability_basis", "source_id", "source_class", "market", "unit_basis",
    "price_basis", "adj_snapshot_id", "value_hash", "quality_flags", "quarantined",
    "ingested_at", "values",
)


class CanonicalError(ValueError):
    """Raised when a row violates the canonical contract."""


def _parse_date(text: Any, label: str) -> date:
    if not isinstance(text, str):
        raise CanonicalError(f"{label} 必須是 YYYY-MM-DD 字串")
    try:
        return date.fromisoformat(text)
    except ValueError:
        raise CanonicalError(f"{label} 不是合法日期: {text!r}") from None


def _parse_datetime(text: Any, label: str) -> datetime:
    if not isinstance(text, str):
        raise CanonicalError(f"{label} 必須是 ISO 8601 字串")
    normalized = text[:-1] + "+00:00" if text.endswith("Z") else text
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        raise CanonicalError(f"{label} 不是合法時間: {text!r}") from None


def build_row_key(spec: DatasetSpec, key_values: Mapping[str, Any]) -> str:
    """Join the declared key fields in their declared order."""
    missing = [name for name in spec.key_fields if name not in key_values]
    if missing:
        raise CanonicalError(f"{spec.name} 缺少 key 欄位: {missing}")
    extra = set(key_values) - set(spec.key_fields)
    if extra:
        raise CanonicalError(f"{spec.name} 收到多餘的 key 欄位: {sorted(extra)}")
    parts = []
    for name in spec.key_fields:
        part = str(key_values[name]).strip()
        if part == "":
            raise CanonicalError(f"{spec.name} 的 key 欄位 {name} 不可為空")
        if KEY_SEPARATOR in part:
            raise CanonicalError(f"{spec.name} 的 key 欄位 {name} 不可包含分隔字元 {KEY_SEPARATOR!r}")
        parts.append(part)
    return KEY_SEPARATOR.join(parts)


@dataclass(frozen=True)
class QuarantineDecision:
    """Why a row was held back, or that it was not."""

    quarantined: bool
    reasons: tuple[str, ...]


def quarantine_decision(
    *,
    availability_basis: str,
    unit_basis: str,
    market: str,
    forced: bool = False,
) -> QuarantineDecision:
    """Apply the three envelope fail-closed triggers plus any caller-forced hold."""
    envelope = {"availability_basis": availability_basis, "unit_basis": unit_basis, "market": market}
    reasons = [reason for name, trigger, reason in _QUARANTINE_TRIGGERS if envelope[name] == trigger]
    if forced:
        reasons.append("呼叫端要求隔離")
    return QuarantineDecision(bool(reasons), tuple(reasons))


def build_row(
    *,
    dataset: str,
    key_values: Mapping[str, Any],
    values: Mapping[str, Any],
    row_date: str,
    source_id: str,
    source_class: str,
    ingested_at: str,
    availability_basis: str,
    availability_time: str | None = None,
    market: str = "not_applicable",
    unit_basis: str = "not_applicable",
    price_basis: str = "not_applicable",
    adj_snapshot_id: str | None = None,
    quality_flags: Iterable[str] = (),
    quarantined: bool = False,
) -> dict[str, Any]:
    """Build one validated canonical row, computing row_key and value_hash."""
    spec = get_spec(dataset)
    decision = quarantine_decision(
        availability_basis=availability_basis,
        unit_basis=unit_basis,
        market=market,
        forced=quarantined,
    )
    flags = list(dict.fromkeys(quality_flags))
    if unit_basis == "unknown" and "unit_unconvertible" not in flags:
        flags.append("unit_unconvertible")
    row = {
        "schema": SCHEMA_NAME,
        "schema_version": SCHEMA_VERSION,
        "dataset": spec.name,
        "row_key": build_row_key(spec, key_values),
        "row_date": row_date,
        "availability_time": availability_time,
        "availability_basis": availability_basis,
        "source_id": source_id,
        "source_class": source_class,
        "market": market,
        "unit_basis": unit_basis,
        "price_basis": price_basis,
        "adj_snapshot_id": adj_snapshot_id,
        "value_hash": value_hash(spec, values),
        "quality_flags": flags,
        "quarantined": decision.quarantined,
        "ingested_at": ingested_at,
        "values": dict(values),
    }
    validate_row(row)
    return row


def validate_row(row: Mapping[str, Any]) -> None:
    """Raise CanonicalError unless the row satisfies the whole contract."""
    if not isinstance(row, Mapping):
        raise CanonicalError("canonical 列必須是物件")
    unknown = set(row) - set(_ROW_FIELDS)
    if unknown:
        raise CanonicalError(f"canonical 列含不允許欄位: {sorted(unknown)}")
    missing = [name for name in _ROW_FIELDS if name not in row]
    if missing:
        raise CanonicalError(f"canonical 列缺少欄位: {missing}")

    if row["schema"] != SCHEMA_NAME:
        raise CanonicalError(f"schema 必須是 {SCHEMA_NAME}")
    if row["schema_version"] != SCHEMA_VERSION:
        raise CanonicalError(f"schema_version 必須是 {SCHEMA_VERSION}")

    spec = get_spec(row["dataset"])

    for name, allowed in (
        ("availability_basis", AVAILABILITY_BASES),
        ("source_id", SOURCE_IDS),
        ("source_class", SOURCE_CLASSES),
        ("market", MARKETS),
        ("unit_basis", UNIT_BASES),
        ("price_basis", PRICE_BASES),
    ):
        if row[name] not in allowed:
            raise CanonicalError(f"{name} 不在允許值內: {row[name]!r}")

    if not spec.requires_market and row["market"] != "not_applicable":
        raise CanonicalError(f"{spec.name} 不使用 market，必須為 not_applicable")
    if not spec.requires_unit and row["unit_basis"] != "not_applicable":
        raise CanonicalError(f"{spec.name} 不使用 unit_basis，必須為 not_applicable")
    if not spec.requires_price_basis and row["price_basis"] != "not_applicable":
        raise CanonicalError(f"{spec.name} 不使用 price_basis，必須為 not_applicable")
    if spec.requires_price_basis and row["price_basis"] == "not_applicable":
        raise CanonicalError(f"{spec.name} 必須宣告 price_basis 為 raw 或 adjusted")

    if row["price_basis"] == "adjusted":
        if not isinstance(row["adj_snapshot_id"], str) or not row["adj_snapshot_id"].strip():
            raise CanonicalError("adjusted 價格必須綁定非空的 adj_snapshot_id")
    elif row["adj_snapshot_id"] not in (None, ""):
        raise CanonicalError("只有 adjusted 價格可帶 adj_snapshot_id")

    _parse_date(row["row_date"], "row_date")
    _parse_datetime(row["ingested_at"], "ingested_at")
    if row["availability_time"] is not None:
        available = _parse_datetime(row["availability_time"], "availability_time")
        if available.date() < _parse_date(row["row_date"], "row_date"):
            raise CanonicalError("availability_time 不可早於 row_date")
    elif row["availability_basis"] != "unknown":
        raise CanonicalError("availability_time 為 null 時 availability_basis 必須是 unknown")

    if not isinstance(row["quarantined"], bool):
        raise CanonicalError("quarantined 必須是布林值")
    decision = quarantine_decision(
        availability_basis=row["availability_basis"],
        unit_basis=row["unit_basis"],
        market=row["market"],
    )
    if decision.quarantined and not row["quarantined"]:
        raise CanonicalError("fail-closed 規則要求隔離此列: " + "、".join(decision.reasons))

    flags = row["quality_flags"]
    if not isinstance(flags, list):
        raise CanonicalError("quality_flags 必須是陣列")
    bad_flags = sorted(set(flags) - QUALITY_FLAGS)
    if bad_flags:
        raise CanonicalError(f"未註冊的 quality_flags: {bad_flags}")
    if len(flags) != len(set(flags)):
        raise CanonicalError("quality_flags 不可重複")

    values = row["values"]
    if not isinstance(values, dict) or not values:
        raise CanonicalError("values 必須是非空物件")
    try:
        expected = value_hash(spec, values)
    except SpecError as exc:
        raise CanonicalError(str(exc)) from None
    if row["value_hash"] != expected:
        raise CanonicalError("value_hash 與 values 不符；不可宣告未經計算的 hash")

    if row["row_key"] != row["row_key"].strip() or not row["row_key"]:
        raise CanonicalError("row_key 不可為空或帶前後空白")
    if len(row["row_key"].split(KEY_SEPARATOR)) != len(spec.key_fields):
        raise CanonicalError(f"{spec.name} 的 row_key 應有 {len(spec.key_fields)} 段")


def read_rows(path: str) -> Iterator[dict[str, Any]]:
    """Yield validated rows from a JSON Lines file."""
    with open(path, "r", encoding="utf-8") as handle:
        for number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise CanonicalError(f"第 {number} 行不是合法 JSON: {exc.msg}") from None
            try:
                validate_row(row)
            except CanonicalError as exc:
                raise CanonicalError(f"第 {number} 行不合契約: {exc}") from None
            yield row


def write_rows(path: str, rows: Iterable[Mapping[str, Any]]) -> int:
    """Write validated rows as JSON Lines and return the count."""
    written = 0
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            validate_row(row)
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")
            written += 1
    return written
