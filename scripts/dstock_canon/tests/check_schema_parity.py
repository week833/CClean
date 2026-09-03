#!/usr/bin/env python3
"""Fail when the published JSON schemas and the runtime implementation drift apart.

The JSON schemas under docs/schemas/ are the contract other programs read; the
Python package is what actually enforces it. Two representations of one contract
will diverge unless something compares them, so this check runs in CI. It uses
only the standard library, comparing enum sets, required-field lists and const
values rather than validating documents.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from dstock_canon import canonical, dataset_spec, promotion, receipt  # noqa: E402
from dstock_canon.textio import use_utf8_streams  # noqa: E402

SCHEMA_DIR = REPO_ROOT / "docs" / "schemas"


def _load(name: str) -> dict:
    with open(SCHEMA_DIR / f"{name}.schema.json", encoding="utf-8") as handle:
        return json.load(handle)


class Report:
    def __init__(self) -> None:
        self.problems: list[str] = []

    def same_set(self, label: str, schema_values, code_values) -> None:
        left, right = set(schema_values), set(code_values)
        if left != right:
            self.problems.append(
                f"{label}: schema 多出 {sorted(left - right)}；實作多出 {sorted(right - left)}"
            )

    def same_value(self, label: str, schema_value, code_value) -> None:
        if schema_value != code_value:
            self.problems.append(f"{label}: schema={schema_value!r} 實作={code_value!r}")


def check_canonical(report: Report) -> None:
    schema = _load("canonical_row")
    props = schema["properties"]
    report.same_value("canonical_row.schema", props["schema"]["const"], dataset_spec.SCHEMA_NAME)
    report.same_value("canonical_row.schema_version", props["schema_version"]["const"], dataset_spec.SCHEMA_VERSION)
    report.same_set("canonical_row.required", schema["required"], canonical._ROW_FIELDS)
    report.same_set("canonical_row.properties", props, canonical._ROW_FIELDS)
    report.same_set("canonical_row.dataset", props["dataset"]["enum"], dataset_spec.dataset_names())
    report.same_set("canonical_row.availability_basis", props["availability_basis"]["enum"], dataset_spec.AVAILABILITY_BASES)
    report.same_set("canonical_row.source_id", props["source_id"]["enum"], dataset_spec.SOURCE_IDS)
    report.same_set("canonical_row.source_class", props["source_class"]["enum"], dataset_spec.SOURCE_CLASSES)
    report.same_set("canonical_row.market", props["market"]["enum"], dataset_spec.MARKETS)
    report.same_set("canonical_row.unit_basis", props["unit_basis"]["enum"], dataset_spec.UNIT_BASES)
    report.same_set("canonical_row.price_basis", props["price_basis"]["enum"], dataset_spec.PRICE_BASES)
    report.same_set("canonical_row.quality_flags", props["quality_flags"]["items"]["enum"], canonical.QUALITY_FLAGS)

    # Every envelope value that forces quarantine must have a matching schema rule.
    guarded = [
        (name, rule["if"]["properties"][name]["const"])
        for rule in schema["allOf"]
        for name in rule["if"]["properties"]
        if rule.get("then", {}).get("properties", {}).get("quarantined", {}).get("const") is True
    ]
    report.same_set(
        "canonical_row.quarantine_triggers",
        guarded,
        [(name, trigger) for name, trigger, _ in canonical._QUARANTINE_TRIGGERS],
    )


def check_receipt(report: Report) -> None:
    schema = _load("source_receipt")
    props = schema["properties"]
    report.same_value("source_receipt.schema", props["schema"]["const"], receipt.SCHEMA_NAME)
    report.same_value("source_receipt.schema_version", props["schema_version"]["const"], receipt.SCHEMA_VERSION)
    report.same_set("source_receipt.required", schema["required"], receipt._RECEIPT_FIELDS)
    report.same_set("source_receipt.properties", props, receipt._RECEIPT_FIELDS)
    report.same_set("source_receipt.status", props["status"]["enum"], receipt.STATUSES)
    report.same_set("source_receipt.publishability", props["publishability"]["enum"], receipt.PUBLISHABILITIES)
    report.same_set("source_receipt.source_id", props["source_id"]["enum"], dataset_spec.SOURCE_IDS)
    report.same_set("source_receipt.source_class", props["source_class"]["enum"], dataset_spec.SOURCE_CLASSES)
    report.same_set(
        "source_receipt.failure.reason_code",
        props["failure"]["properties"]["reason_code"]["enum"],
        receipt.FAILURE_REASONS,
    )
    block = props["datasets"]["items"]
    report.same_set("source_receipt.datasets.properties", block["properties"], receipt._DATASET_FIELDS)
    report.same_set("source_receipt.datasets.required", block["required"], receipt._DATASET_FIELDS[:-1])

    # A failed receipt carries no datasets, so the non-empty rule must stay
    # conditional on status the same way the runtime keeps it.
    if "minItems" in props["datasets"]:
        report.problems.append("source_receipt.datasets: minItems 必須是條件式，failed receipt 沒有 dataset")
    conditional = [
        rule for rule in schema["allOf"]
        if rule["if"]["properties"].get("status", {}).get("enum") == ["complete", "partial"]
        and rule["then"]["properties"]["datasets"]["minItems"] == 1
    ]
    if len(conditional) != 1:
        report.problems.append("source_receipt.datasets: 缺少 non-failed 才要求非空的規則")


def check_manifest(report: Report) -> None:
    schema = _load("central_manifest")
    props = schema["properties"]
    report.same_value("central_manifest.schema", props["schema"]["const"], promotion.SCHEMA_NAME)
    report.same_value("central_manifest.schema_version", props["schema_version"]["const"], promotion.SCHEMA_VERSION)
    report.same_set("central_manifest.properties", props, promotion._MANIFEST_FIELDS)
    report.same_set("central_manifest.required", schema["required"], promotion._MANIFEST_FIELDS[:10])
    report.same_set(
        "central_manifest.degradation_level",
        props["degradation_level"]["enum"],
        promotion.LEVEL_PUBLISHABILITY,
    )

    # Each level's publishability must be pinned identically on both sides.
    for rule in schema["allOf"]:
        condition = rule["if"]["properties"]["degradation_level"]
        levels = [condition["const"]] if "const" in condition else condition["enum"]
        expected = rule["then"]["properties"]["publishability"]["const"]
        for level in levels:
            report.same_value(
                f"central_manifest.publishability[{level}]",
                expected,
                promotion.LEVEL_PUBLISHABILITY[level],
            )


def main() -> int:
    use_utf8_streams()
    report = Report()
    check_canonical(report)
    check_receipt(report)
    check_manifest(report)
    if report.problems:
        print("[ERROR] JSON schema 與實作不一致:", file=sys.stderr)
        for problem in report.problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    print("[OK] docs/schemas 與 dstock_canon 實作一致。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
