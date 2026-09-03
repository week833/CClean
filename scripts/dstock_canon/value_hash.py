"""The single shared value-hash implementation.

Central market_update and the collect tool MUST both import ``value_hash`` from
here. Two independent implementations will diverge on rounding, missing-value
encoding or field ordering, and the reconciliation match rate would then measure
the implementations rather than the data.

Algorithm (contract, do not change without bumping SCHEMA_VERSION):

1. Take the dataset's declared business-field whitelist; ignore everything else.
2. Numeric fields become Decimal, quantized to the declared decimal places with
   ROUND_HALF_UP, rendered in plain notation with trailing zeros stripped.
3. Missing values become the empty string, never 0, None or "nan".
4. Fields are sorted by name and joined as "name=value" with newlines.
5. UTF-8 encode, then lowercase hex sha256.
"""

from __future__ import annotations

import hashlib
import math
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Mapping

from .dataset_spec import DatasetSpec, FieldSpec, SpecError, get_spec

_MISSING = ""
_TRUE = "true"
_FALSE = "false"


class ValueError_(ValueError):
    """Raised when a business value cannot be normalized under its field spec."""


def _is_missing(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, str) and value.strip() == "":
        return True
    if isinstance(value, float) and math.isnan(value):
        return True
    return False


def _normalize_decimal(value: Any, spec: FieldSpec) -> str:
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError_(f"{spec.name} 不接受無窮值")
    try:
        dec = Decimal(str(value))
    except InvalidOperation:
        raise ValueError_(f"{spec.name} 無法轉為 Decimal: {value!r}") from None
    if not dec.is_finite():
        raise ValueError_(f"{spec.name} 不接受無窮值或 NaN")
    quantum = Decimal(1).scaleb(-spec.places)
    text = format(dec.quantize(quantum, rounding=ROUND_HALF_UP), "f")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    if text in ("", "-", "-0"):
        text = "0"
    return text


def _normalize_integer(value: Any, spec: FieldSpec) -> str:
    if isinstance(value, bool):
        raise ValueError_(f"{spec.name} 是整數欄位，不接受布林值")
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError_(f"{spec.name} 不接受無窮值")
        if not float(value).is_integer():
            raise ValueError_(f"{spec.name} 是整數欄位，不接受 {value!r}")
        value = int(value)
    try:
        return str(int(Decimal(str(value))))
    except (InvalidOperation, ValueError):
        raise ValueError_(f"{spec.name} 無法轉為整數: {value!r}") from None


def _normalize_bool(value: Any, spec: FieldSpec) -> str:
    if isinstance(value, bool):
        return _TRUE if value else _FALSE
    if isinstance(value, str) and value.strip().lower() in (_TRUE, _FALSE):
        return value.strip().lower()
    raise ValueError_(f"{spec.name} 是布林欄位，不接受 {value!r}")


def normalize_field(value: Any, spec: FieldSpec) -> str:
    """Return the canonical string form of one business value."""
    if _is_missing(value):
        return _MISSING
    if spec.kind == "decimal":
        return _normalize_decimal(value, spec)
    if spec.kind == "integer":
        return _normalize_integer(value, spec)
    if spec.kind == "bool":
        return _normalize_bool(value, spec)
    return str(value).strip()


def canonical_payload(dataset: str | DatasetSpec, values: Mapping[str, Any]) -> str:
    """Return the exact string that gets hashed. Useful when debugging a mismatch."""
    spec = dataset if isinstance(dataset, DatasetSpec) else get_spec(dataset)
    unknown = set(values) - set(spec.field_names())
    if unknown:
        raise SpecError(f"{spec.name} 收到白名單外的欄位: {sorted(unknown)}")
    lines = []
    for name in sorted(spec.field_names()):
        lines.append(f"{name}={normalize_field(values.get(name), spec.field_spec(name))}")
    return "\n".join(lines)


def value_hash(dataset: str | DatasetSpec, values: Mapping[str, Any]) -> str:
    """Return the lowercase hex sha256 of the canonical payload."""
    return hashlib.sha256(canonical_payload(dataset, values).encode("utf-8")).hexdigest()


def rollup_hash(row_hashes: Mapping[str, str]) -> str:
    """Fold per-row hashes into one dataset hash, ordered by row_key.

    ``row_hashes`` maps row_key to that row's value_hash. Quarantined rows must be
    excluded by the caller so that the rollup describes only publishable content.
    """
    digest = hashlib.sha256()
    for row_key in sorted(row_hashes):
        digest.update(row_key.encode("utf-8"))
        digest.update(b"=")
        digest.update(row_hashes[row_key].encode("utf-8"))
        digest.update(b"\n")
    return digest.hexdigest()
