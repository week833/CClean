"""Shadow compare and the backup-eligibility ledger.

A backup source earns the right to substitute for the primary by measurement,
not by declaration. Both sources run every day; this module compares them row by
row and keeps the running record that decides whether a dataset may be used for
failover.

Three bands per trading day, evaluated per dataset:

* qualifying  match_rate >= 0.999 and no backup-only keys -> streak advances
* warning     0.99 <= match_rate < 0.999                  -> streak resets, class kept
* breach      match_rate < 0.99, or any backup-only key    -> demote, streak resets

Backup-only keys are treated as a breach rather than a warning: a row the primary
never produced is a phantom, which is worse than a value disagreement.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Iterable, Mapping, Sequence

from .dataset_spec import get_spec

PROMOTION_STREAK = 20
QUALIFY_RATE = 0.999
BREACH_RATE = 0.99
HISTORY_LIMIT = 40

BAND_QUALIFYING = "qualifying"
BAND_WARNING = "warning"
BAND_BREACH = "breach"
BAND_NO_EVIDENCE = "no_evidence"


class ReconcileError(ValueError):
    """Raised when a comparison or ledger entry is malformed."""


def _usable(rows: Iterable[Mapping[str, Any]]) -> dict[str, str]:
    table: dict[str, str] = {}
    for row in rows:
        if row["quarantined"]:
            continue
        key = row["row_key"]
        if key in table:
            raise ReconcileError(f"{row['dataset']} 出現重複 row_key: {key}")
        table[key] = row["value_hash"]
    return table


def compare_dataset(
    dataset: str,
    primary_rows: Sequence[Mapping[str, Any]],
    backup_rows: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    """Compare one dataset's usable rows across the two sources."""
    get_spec(dataset)
    primary = _usable(primary_rows)
    backup = _usable(backup_rows)
    shared = primary.keys() & backup.keys()
    match_rows = sum(1 for key in shared if primary[key] == backup[key])
    compared = len(shared)
    return {
        "dataset": dataset,
        "compared_rows": compared,
        "match_rows": match_rows,
        "match_rate": (match_rows / compared) if compared else None,
        "key_only_in_primary": len(primary.keys() - backup.keys()),
        "key_only_in_backup": len(backup.keys() - primary.keys()),
        "mismatched_keys": sorted(key for key in shared if primary[key] != backup[key])[:20],
    }


def classify(comparison: Mapping[str, Any]) -> str:
    """Return the band for one day's comparison of one dataset."""
    rate = comparison["match_rate"]
    if comparison["key_only_in_backup"]:
        return BAND_BREACH
    if rate is None:
        return BAND_NO_EVIDENCE
    if rate < BREACH_RATE:
        return BAND_BREACH
    if rate >= QUALIFY_RATE:
        return BAND_QUALIFYING
    return BAND_WARNING


@dataclass
class DatasetLedger:
    """Running eligibility state for one dataset."""

    streak: int = 0
    source_class: str = "reference_only"
    history: list[dict[str, Any]] = field(default_factory=list)


class EligibilityLedger:
    """Persistent record of which datasets the backup may substitute for."""

    def __init__(self, state: Mapping[str, Mapping[str, Any]] | None = None) -> None:
        self._state: dict[str, DatasetLedger] = {}
        for dataset, entry in (state or {}).items():
            get_spec(dataset)
            self._state[dataset] = DatasetLedger(
                streak=int(entry.get("streak", 0)),
                source_class=entry.get("source_class", "reference_only"),
                history=list(entry.get("history", [])),
            )

    def _entry(self, dataset: str) -> DatasetLedger:
        get_spec(dataset)
        return self._state.setdefault(dataset, DatasetLedger())

    def record(self, trading_day: str, comparison: Mapping[str, Any]) -> dict[str, Any]:
        """Apply one day's comparison and return the resulting decision."""
        dataset = comparison["dataset"]
        entry = self._entry(dataset)
        band = classify(comparison)
        before = entry.source_class

        if band == BAND_BREACH:
            entry.streak = 0
            entry.source_class = "reference_only"
        elif band == BAND_QUALIFYING:
            entry.streak += 1
            if entry.streak >= PROMOTION_STREAK:
                entry.source_class = "backup"
        elif band == BAND_WARNING:
            entry.streak = 0

        decision = {
            "trading_day": trading_day,
            "dataset": dataset,
            "band": band,
            "match_rate": comparison["match_rate"],
            "key_only_in_backup": comparison["key_only_in_backup"],
            "streak": entry.streak,
            "source_class_before": before,
            "source_class_after": entry.source_class,
        }
        entry.history.append(decision)
        del entry.history[:-HISTORY_LIMIT]
        return decision

    def eligible(self, dataset: str) -> bool:
        """True when the backup may substitute for this dataset today."""
        return self._entry(dataset).source_class == "backup"

    def eligible_datasets(self) -> tuple[str, ...]:
        return tuple(sorted(name for name, entry in self._state.items() if entry.source_class == "backup"))

    def streak(self, dataset: str) -> int:
        return self._entry(dataset).streak

    def to_dict(self) -> dict[str, Any]:
        return {
            dataset: {
                "streak": entry.streak,
                "source_class": entry.source_class,
                "history": entry.history,
            }
            for dataset, entry in sorted(self._state.items())
        }

    @classmethod
    def load(cls, path: str) -> "EligibilityLedger":
        try:
            with open(path, "r", encoding="utf-8") as handle:
                return cls(json.load(handle))
        except FileNotFoundError:
            return cls()

    def save(self, path: str) -> None:
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(self.to_dict(), handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
