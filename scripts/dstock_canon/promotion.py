"""The single promotion gate and the central manifest builder.

Neither source decides its own eligibility. This module takes both receipts plus
the eligibility ledger, assigns each required dataset to a source, and derives the
degradation level that the central manifest publishes.

Levels:

* L0  primary covers every required dataset with clean PIT      -> publishable
* L1  primary contributes nothing, backup covers everything      -> degraded
* L2  primary covers part, eligible backup fills the remainder   -> degraded
* L3  the union still leaves a gap                               -> blocked
"""

from __future__ import annotations

import hashlib
import json
from typing import Any, Iterable, Mapping, Sequence

from .dataset_spec import AVAILABILITY_RANK, SOURCE_CLASS_RANK, get_spec
from .governance import Governance, default_governance
from .receipt import validate_receipt

SCHEMA_NAME = "dstock.market.central_manifest"
SCHEMA_VERSION = 1

LEVEL_PUBLISHABILITY = {"L0": "publishable", "L1": "degraded", "L2": "degraded", "L3": "blocked"}
LEVEL_STATUS = {"L0": "complete", "L1": "complete", "L2": "partial", "L3": "failed"}


class PromotionError(ValueError):
    """Raised when the gate is given inconsistent inputs."""


def receipt_hash(receipt: Mapping[str, Any]) -> str:
    """Stable sha256 of a receipt, used as the manifest's reference to it."""
    payload = json.dumps(receipt, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _usable_datasets(receipt: Mapping[str, Any] | None) -> set[str]:
    """Datasets a receipt covers completely, with no future rows."""
    if not receipt or receipt["status"] == "failed":
        return set()
    return {
        block["dataset"]
        for block in receipt["datasets"]
        if block["coverage_to_cutoff"] >= 1.0 and block["future_row_count"] == 0
    }


def _pit_clean(receipt: Mapping[str, Any] | None) -> bool:
    if not receipt:
        return False
    pit = receipt["pit"]
    return not pit["future_row_count"] and not pit["unknown_availability_rows"]


def decide(
    *,
    required_datasets: Iterable[str],
    primary_receipt: Mapping[str, Any] | None,
    backup_receipt: Mapping[str, Any] | None,
    eligible_datasets: Iterable[str],
    governance: Governance | None = None,
) -> dict[str, Any]:
    """Assign each required dataset to a source and derive the degradation level.

    ``eligible_datasets`` is what the reconciliation ledger *measured* as good
    enough to substitute. ``governance`` is whether a decision has *authorised*
    substitution at all. Both are required; the default governance ratifies only
    ``primary``, so a caller that has not adopted ADR-0002 cannot accidentally
    let a backup row through by passing a populated eligible_datasets.
    """
    required = set()
    for dataset in required_datasets:
        get_spec(dataset)
        required.add(dataset)
    if not required:
        raise PromotionError("required_datasets 不可為空")

    if primary_receipt is not None:
        validate_receipt(primary_receipt)
        if primary_receipt["source_class"] != "primary":
            raise PromotionError("primary_receipt 的 source_class 必須是 primary")
    if backup_receipt is not None:
        validate_receipt(backup_receipt)
        if backup_receipt["source_class"] == "primary":
            raise PromotionError("backup_receipt 的 source_class 不可是 primary")

    governance = governance or default_governance()
    measured_eligible = set(eligible_datasets)
    eligible = measured_eligible if governance.allows("backup") else set()

    primary_ok = _usable_datasets(primary_receipt) & required
    if not _pit_clean(primary_receipt):
        primary_ok = set()

    # Report a governance refusal only where it changed the outcome. On a healthy
    # day the primary covers everything and the unused backup is not news.
    governance_withheld = sorted((measured_eligible & required) - eligible - primary_ok)
    backup_ok = (_usable_datasets(backup_receipt) & required & eligible)
    if not _pit_clean(backup_receipt):
        backup_ok = set()

    assignment: dict[str, str] = {}
    for dataset in sorted(required):
        if dataset in primary_ok:
            assignment[dataset] = primary_receipt["source_id"]
        elif dataset in backup_ok:
            assignment[dataset] = backup_receipt["source_id"]

    covered = set(assignment)
    if covered != required:
        level = "L3"
    elif primary_ok == required:
        level = "L0"
    elif not primary_ok:
        level = "L1"
    else:
        level = "L2"

    if level == "L0":
        effective = primary_receipt["source_id"]
    elif level == "L1":
        effective = backup_receipt["source_id"]
    elif level == "L2":
        effective = "mixed"
    else:
        effective = "none"

    result = {
        "degradation_level": level,
        "effective_source": effective,
        "assignment": assignment,
        "uncovered_datasets": sorted(required - covered),
        "primary_covered": sorted(primary_ok),
        "backup_covered": sorted(backup_ok),
        "ineligible_datasets": sorted((required & _usable_datasets(backup_receipt)) - eligible),
        "governance": governance.describe(),
        "governance_withheld": governance_withheld,
    }
    if governance_withheld:
        # Say why, so an operator reads a governance decision rather than a bug.
        result["governance_note"] = governance.withheld_reason("backup")
    return result


def _rank_key(row: Mapping[str, Any]) -> tuple[int, int, str]:
    return (
        SOURCE_CLASS_RANK[row["source_class"]],
        AVAILABILITY_RANK[row["availability_basis"]],
        row["ingested_at"],
    )


def merge_rows(rows: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    """Resolve multi-source rows by precedence, quarantining unresolved conflicts."""
    grouped: dict[tuple[str, str], list[Mapping[str, Any]]] = {}
    for row in rows:
        if row["source_class"] == "reference_only":
            continue
        grouped.setdefault((row["dataset"], row["row_key"]), []).append(row)

    merged: list[Mapping[str, Any]] = []
    conflicts: list[dict[str, Any]] = []
    for (dataset, row_key), candidates in sorted(grouped.items()):
        if len({row["value_hash"] for row in candidates}) == 1:
            merged.append(min(candidates, key=_rank_key))
            continue
        ranked = sorted(candidates, key=_rank_key)
        if _rank_key(ranked[0]) == _rank_key(ranked[1]):
            conflicts.append({
                "dataset": dataset,
                "row_key": row_key,
                "sources": sorted({row["source_id"] for row in candidates}),
            })
            held = dict(ranked[0])
            held["quarantined"] = True
            merged.append(held)
            continue
        merged.append(ranked[0])
    return {"rows": merged, "conflicts": conflicts}


def plan_restatements(
    current_rows: Sequence[Mapping[str, Any]],
    recovered_primary_rows: Sequence[Mapping[str, Any]],
    *,
    restated_at: str,
) -> list[dict[str, Any]]:
    """List the rows a recovered primary would overwrite, for the audit trail.

    The caller keeps the superseded rows in history; nothing here deletes them.
    """
    current = {(row["dataset"], row["row_key"]): row for row in current_rows}
    records = []
    for row in recovered_primary_rows:
        key = (row["dataset"], row["row_key"])
        held = current.get(key)
        if held is None or held["source_id"] == row["source_id"]:
            continue
        if held["value_hash"] == row["value_hash"]:
            continue
        records.append({
            "dataset": row["dataset"],
            "row_key": row["row_key"],
            "from_source": held["source_id"],
            "to_source": row["source_id"],
            "restated_at": restated_at,
        })
    return sorted(records, key=lambda item: (item["dataset"], item["row_key"]))


def build_manifest(
    *,
    asof: str,
    expected_asof: str,
    generated_at: str,
    decision: Mapping[str, Any],
    primary_receipt: Mapping[str, Any] | None,
    backup_receipt: Mapping[str, Any] | None,
    primary_receipt_path: str | None = None,
    backup_receipt_path: str | None = None,
    reconciliation: Sequence[Mapping[str, Any]] = (),
    conflicts: Sequence[Mapping[str, Any]] = (),
    restatements: Sequence[Mapping[str, Any]] = (),
) -> dict[str, Any]:
    """Assemble the central manifest from a gate decision."""
    level = decision["degradation_level"]
    if level not in LEVEL_PUBLISHABILITY:
        raise PromotionError(f"未知的 degradation_level: {level}")

    sources = []
    for receipt, path in ((primary_receipt, primary_receipt_path), (backup_receipt, backup_receipt_path)):
        if receipt is None:
            continue
        coverage = [block["coverage_to_cutoff"] for block in receipt["datasets"]]
        sources.append({
            "source_id": receipt["source_id"],
            "source_class": receipt["source_class"],
            "status": receipt["status"],
            "publishability": receipt["publishability"],
            "receipt_path": path or f"receipts/{receipt['source_id']}/{receipt['asof']}.json",
            "receipt_hash": receipt_hash(receipt),
            "coverage_to_cutoff": min(coverage) if coverage else 0.0,
        })
    if not sources:
        raise PromotionError("manifest 至少需要一份來源 receipt")

    manifest = {
        "schema": SCHEMA_NAME,
        "schema_version": SCHEMA_VERSION,
        "asof": asof,
        "expected_asof": expected_asof,
        "generated_at": generated_at,
        "status": LEVEL_STATUS[level],
        "publishability": LEVEL_PUBLISHABILITY[level],
        "sources": sources,
        "effective_source": decision["effective_source"],
        "degradation_level": level,
        "reconciliation": {"compared_datasets": [
            {name: item[name] for name in (
                "dataset", "compared_rows", "match_rows", "match_rate",
                "key_only_in_primary", "key_only_in_backup",
            ) if name in item}
            for item in reconciliation
        ]},
        "conflicts": list(conflicts),
        "restatements": list(restatements),
    }
    validate_manifest(manifest)
    return manifest


_MANIFEST_FIELDS = (
    "schema", "schema_version", "asof", "expected_asof", "generated_at", "status",
    "publishability", "sources", "effective_source", "degradation_level",
    "reconciliation", "conflicts", "restatements",
)


def validate_manifest(manifest: Mapping[str, Any]) -> None:
    """Raise PromotionError unless the manifest satisfies the contract."""
    unknown = set(manifest) - set(_MANIFEST_FIELDS)
    if unknown:
        raise PromotionError(f"manifest 含不允許欄位: {sorted(unknown)}")
    missing = [name for name in _MANIFEST_FIELDS[:10] if name not in manifest]
    if missing:
        raise PromotionError(f"manifest 缺少欄位: {missing}")
    if manifest["schema"] != SCHEMA_NAME:
        raise PromotionError(f"schema 必須是 {SCHEMA_NAME}")
    if manifest["schema_version"] != SCHEMA_VERSION:
        raise PromotionError(f"schema_version 必須是 {SCHEMA_VERSION}")
    level = manifest["degradation_level"]
    if level not in LEVEL_PUBLISHABILITY:
        raise PromotionError(f"未知的 degradation_level: {level}")
    if manifest["publishability"] != LEVEL_PUBLISHABILITY[level]:
        raise PromotionError(f"{level} 的 publishability 必須是 {LEVEL_PUBLISHABILITY[level]}")
    if manifest["status"] != LEVEL_STATUS[level]:
        raise PromotionError(f"{level} 的 status 必須是 {LEVEL_STATUS[level]}")
    if not manifest["sources"]:
        raise PromotionError("manifest 至少需要一份來源")
    for source in manifest["sources"]:
        if len(source.get("receipt_hash", "")) != 64:
            raise PromotionError("receipt_hash 必須是 sha256 十六進位")


def write_manifest(path: str, manifest: Mapping[str, Any]) -> None:
    validate_manifest(manifest)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
