"""Command line entry point for the shared canonical contract.

Machine-readable results go to stdout as JSON; human messages go to stderr, so a
caller can pipe stdout straight into a parser without redirecting stderr into it.

    python -m dstock_canon validate-rows  <rows.jsonl>
    python -m dstock_canon validate-receipt <receipt.json>
    python -m dstock_canon build-receipt --source-id ... --rows daily_price=<path> ...
    python -m dstock_canon compare --trading-day ... --primary ds=<path> --backup ds=<path>
    python -m dstock_canon promote --required daily_price --primary-receipt ... --backup-receipt ...
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from typing import Any, Sequence

from .canonical import CanonicalError, read_rows
from .dataset_spec import dataset_names
from .promotion import PromotionError, build_manifest, decide, write_manifest
from .receipt import ReceiptError, build_receipt, read_receipt, write_receipt
from .reconcile import EligibilityLedger, compare_dataset


def _emit(payload: Any) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2, sort_keys=True)
    sys.stdout.write("\n")


def _pairs(items: Sequence[str], label: str) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for item in items:
        if "=" not in item:
            raise SystemExit(f"[ERROR] {label} 必須是 dataset=值 的形式: {item}")
        dataset, value = item.split("=", 1)
        if dataset not in dataset_names():
            raise SystemExit(f"[ERROR] 未註冊的 dataset: {dataset}")
        mapping[dataset] = value
    return mapping


def _load_rows(paths: dict[str, str]) -> dict[str, list[dict[str, Any]]]:
    rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for dataset, path in paths.items():
        for row in read_rows(path):
            if row["dataset"] != dataset:
                raise SystemExit(f"[ERROR] {path} 內含 {row['dataset']}，與宣告的 {dataset} 不符")
            rows[dataset].append(row)
    return dict(rows)


def _cmd_validate_rows(args: argparse.Namespace) -> int:
    counts: dict[str, int] = defaultdict(int)
    quarantined: dict[str, int] = defaultdict(int)
    for row in read_rows(args.path):
        counts[row["dataset"]] += 1
        if row["quarantined"]:
            quarantined[row["dataset"]] += 1
    _emit({"ok": True, "rows": dict(counts), "quarantined": dict(quarantined)})
    return 0


def _cmd_validate_receipt(args: argparse.Namespace) -> int:
    receipt = read_receipt(args.path)
    _emit({
        "ok": True,
        "source_id": receipt["source_id"],
        "status": receipt["status"],
        "publishability": receipt["publishability"],
        "datasets": [block["dataset"] for block in receipt["datasets"]],
    })
    return 0


def _cmd_build_receipt(args: argparse.Namespace) -> int:
    rows = _load_rows(_pairs(args.rows, "--rows"))
    expected = {dataset: int(value) for dataset, value in _pairs(args.expected, "--expected").items()}
    receipt = build_receipt(
        source_id=args.source_id,
        source_class=args.source_class,
        asof=args.asof,
        expected_asof=args.expected_asof or args.asof,
        generated_at=args.generated_at,
        rows_by_dataset=rows,
        expected_rows=expected,
        research_cutoff=args.research_cutoff,
        evidence={"code_version": args.code_version, "config_hash": args.config_hash},
    )
    if args.output:
        write_receipt(args.output, receipt)
        print(f"[OK] receipt 已寫入 {args.output}", file=sys.stderr)
    _emit(receipt)
    return 0


def _cmd_compare(args: argparse.Namespace) -> int:
    primary = _load_rows(_pairs(args.primary, "--primary"))
    backup = _load_rows(_pairs(args.backup, "--backup"))
    ledger = EligibilityLedger.load(args.ledger) if args.ledger else EligibilityLedger()

    results = []
    for dataset in sorted(set(primary) | set(backup)):
        comparison = compare_dataset(dataset, primary.get(dataset, []), backup.get(dataset, []))
        decision = ledger.record(args.trading_day, comparison)
        results.append({**comparison, **{k: decision[k] for k in ("band", "streak", "source_class_after")}})

    if args.ledger:
        ledger.save(args.ledger)
        print(f"[OK] 資格帳本已更新 {args.ledger}", file=sys.stderr)
    _emit({"trading_day": args.trading_day, "comparisons": results,
           "eligible_datasets": list(ledger.eligible_datasets())})
    return 0


def _cmd_promote(args: argparse.Namespace) -> int:
    primary = read_receipt(args.primary_receipt) if args.primary_receipt else None
    backup = read_receipt(args.backup_receipt) if args.backup_receipt else None
    ledger = EligibilityLedger.load(args.ledger) if args.ledger else EligibilityLedger()

    result = decide(
        required_datasets=args.required,
        primary_receipt=primary,
        backup_receipt=backup,
        eligible_datasets=ledger.eligible_datasets(),
    )
    manifest = build_manifest(
        asof=args.asof,
        expected_asof=args.expected_asof or args.asof,
        generated_at=args.generated_at,
        decision=result,
        primary_receipt=primary,
        backup_receipt=backup,
        primary_receipt_path=args.primary_receipt,
        backup_receipt_path=args.backup_receipt,
    )
    if args.output:
        write_manifest(args.output, manifest)
        print(f"[OK] manifest 已寫入 {args.output}", file=sys.stderr)
    _emit({"decision": result, "manifest": manifest})
    return 0 if result["degradation_level"] != "L3" else 3


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="dstock_canon", description="D-stock 雙來源互補契約工具")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("validate-rows", help="驗證 canonical JSON Lines")
    p.add_argument("path")
    p.set_defaults(handler=_cmd_validate_rows)

    p = sub.add_parser("validate-receipt", help="驗證 source receipt")
    p.add_argument("path")
    p.set_defaults(handler=_cmd_validate_receipt)

    p = sub.add_parser("build-receipt", help="由 canonical 列產生 receipt")
    p.add_argument("--source-id", required=True)
    p.add_argument("--source-class", required=True)
    p.add_argument("--asof", required=True)
    p.add_argument("--expected-asof")
    p.add_argument("--generated-at", required=True)
    p.add_argument("--rows", action="append", default=[], metavar="DATASET=PATH")
    p.add_argument("--expected", action="append", default=[], metavar="DATASET=ROWS")
    p.add_argument("--research-cutoff")
    p.add_argument("--code-version", required=True)
    p.add_argument("--config-hash", required=True)
    p.add_argument("-o", "--output")
    p.set_defaults(handler=_cmd_build_receipt)

    p = sub.add_parser("compare", help="兩來源 shadow compare 並更新資格帳本")
    p.add_argument("--trading-day", required=True)
    p.add_argument("--primary", action="append", default=[], metavar="DATASET=PATH")
    p.add_argument("--backup", action="append", default=[], metavar="DATASET=PATH")
    p.add_argument("--ledger")
    p.set_defaults(handler=_cmd_compare)

    p = sub.add_parser("promote", help="執行 promotion gate 並產生 central manifest")
    p.add_argument("--required", action="append", default=[], required=True)
    p.add_argument("--primary-receipt")
    p.add_argument("--backup-receipt")
    p.add_argument("--ledger")
    p.add_argument("--asof", required=True)
    p.add_argument("--expected-asof")
    p.add_argument("--generated-at", required=True)
    p.add_argument("-o", "--output")
    p.set_defaults(handler=_cmd_promote)

    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.handler(args)
    except (CanonicalError, ReceiptError, PromotionError, ValueError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
