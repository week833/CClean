"""Which source classes are authorised to enter the promotion gate.

Measurement and authorisation are deliberately separate concerns:

* reconcile.EligibilityLedger measures whether a backup dataset *matches* the
  primary well enough to stand in for it. That measurement can and should start
  immediately — twenty trading days of evidence is exactly what an ADR needs.
* This module records whether a governance decision has *authorised* that
  substitution. Until the ADR exists, no amount of measured agreement lets a
  backup row reach shared_market_data.

The default is the safe one: only ``primary`` is ratified, so decide() withholds
every backup dataset. Making that a code path rather than a calling convention
means nobody has to remember to pass an empty eligible_datasets — forgetting is
not one of the available outcomes.

``reference_only`` can never be ratified. It is not a governance setting.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any, Iterable, Mapping

SCHEMA_NAME = "dstock.market.source_governance"
SCHEMA_VERSION = 1

ENV_VAR = "DSTOCK_GOVERNANCE"

RATIFIABLE_CLASSES = ("primary", "backup")
NEVER_RATIFIABLE = ("reference_only",)

_GOVERNANCE_FIELDS = ("schema", "schema_version", "ratified_classes", "adr", "ratified_at", "note")


class GovernanceError(ValueError):
    """Raised when a governance declaration is malformed or unsafe."""


@dataclass(frozen=True)
class Governance:
    """The source classes a governance decision has authorised."""

    ratified_classes: frozenset[str]
    adr: str
    ratified_at: str | None = None
    note: str = ""

    def allows(self, source_class: str) -> bool:
        return source_class in self.ratified_classes

    def withheld_reason(self, source_class: str) -> str:
        return (
            f"{source_class} 尚未由治理決策批准（目前依據 {self.adr}，"
            f"已批准: {sorted(self.ratified_classes)}）"
        )

    def describe(self) -> dict[str, Any]:
        return {
            "adr": self.adr,
            "ratified_classes": sorted(self.ratified_classes),
            "ratified_at": self.ratified_at,
        }


#: Used whenever no governance file is declared. Primary only — the pre-ADR state.
DEFAULT = Governance(
    ratified_classes=frozenset({"primary"}),
    adr="ADR-0001",
    ratified_at=None,
    note="尚未採用 ADR-0002；backup 不得替補，僅 primary 可進入 promotion gate。",
)


def default_governance() -> Governance:
    return DEFAULT


def from_mapping(data: Mapping[str, Any]) -> Governance:
    """Build a Governance from a declaration, rejecting unsafe ones."""
    if not isinstance(data, Mapping):
        raise GovernanceError("治理宣告必須是物件")
    unknown = set(data) - set(_GOVERNANCE_FIELDS)
    if unknown:
        raise GovernanceError(f"治理宣告含不允許欄位: {sorted(unknown)}")
    if data.get("schema") != SCHEMA_NAME:
        raise GovernanceError(f"schema 必須是 {SCHEMA_NAME}")
    if data.get("schema_version") != SCHEMA_VERSION:
        raise GovernanceError(f"schema_version 必須是 {SCHEMA_VERSION}")

    classes = data.get("ratified_classes")
    if not isinstance(classes, list) or not classes:
        raise GovernanceError("ratified_classes 必須是非空陣列")
    forbidden = sorted(set(classes) & set(NEVER_RATIFIABLE))
    if forbidden:
        raise GovernanceError(f"{forbidden} 永遠不可被批准；這不是治理選項")
    unknown_classes = sorted(set(classes) - set(RATIFIABLE_CLASSES))
    if unknown_classes:
        raise GovernanceError(f"未知的 source_class: {unknown_classes}")
    if "primary" not in classes:
        raise GovernanceError("primary 是 system of record，必須列在 ratified_classes")

    adr = data.get("adr")
    if not isinstance(adr, str) or not adr.strip():
        raise GovernanceError("必須註明批准依據的 ADR")
    if "backup" in classes and not data.get("ratified_at"):
        raise GovernanceError("批准 backup 必須註明 ratified_at，作為稽核依據")

    return Governance(
        ratified_classes=frozenset(classes),
        adr=adr.strip(),
        ratified_at=data.get("ratified_at"),
        note=data.get("note", ""),
    )


def load(path: str | None = None) -> Governance:
    """Load the declaration from ``path``, the DSTOCK_GOVERNANCE env var, or fall back.

    A missing file is not an error: it means no governance decision has been
    recorded yet, which is exactly the pre-ADR state DEFAULT describes. A file
    that exists but is malformed IS an error — a broken declaration must never
    silently widen what the gate accepts.
    """
    target = path or os.environ.get(ENV_VAR)
    if not target:
        return DEFAULT
    try:
        with open(target, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        return DEFAULT
    except json.JSONDecodeError as exc:
        raise GovernanceError(f"治理宣告不是合法 JSON: {exc.msg}") from None
    return from_mapping(data)
