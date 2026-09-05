"""Shared canonical data contract for central market_update and the collect tool.

Import this package from both programs. It is the single implementation of the
join keys, value hash, fail-closed rules, receipt shape, shadow compare and
promotion gate described in docs/data_source_failover_plan.md.
"""

from __future__ import annotations

from .canonical import CanonicalError, build_row, build_row_key, read_rows, validate_row, write_rows
from .dataset_spec import SCHEMA_VERSION, DATASET_SPECS, SpecError, dataset_names, get_spec
from .governance import Governance, GovernanceError, default_governance, load as load_governance
from .promotion import (
    PromotionError,
    build_manifest,
    decide,
    merge_rows,
    plan_restatements,
    validate_manifest,
    write_manifest,
)
from .receipt import ReceiptError, build_receipt, failed_receipt, read_receipt, validate_receipt, write_receipt
from .reconcile import EligibilityLedger, ReconcileError, classify, compare_dataset
from .value_hash import canonical_payload, rollup_hash, value_hash

__all__ = [
    "SCHEMA_VERSION",
    "DATASET_SPECS",
    "CanonicalError",
    "EligibilityLedger",
    "Governance",
    "GovernanceError",
    "PromotionError",
    "ReceiptError",
    "ReconcileError",
    "SpecError",
    "build_manifest",
    "build_receipt",
    "build_row",
    "build_row_key",
    "canonical_payload",
    "classify",
    "compare_dataset",
    "dataset_names",
    "decide",
    "failed_receipt",
    "default_governance",
    "get_spec",
    "load_governance",
    "merge_rows",
    "plan_restatements",
    "read_receipt",
    "read_rows",
    "rollup_hash",
    "validate_manifest",
    "validate_receipt",
    "validate_row",
    "value_hash",
    "write_manifest",
    "write_receipt",
    "write_rows",
]
