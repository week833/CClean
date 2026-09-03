"""End-to-end CLI flow: rows -> receipts -> shadow compare -> promotion gate."""

from __future__ import annotations

import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

from dstock_canon.canonical import write_rows
from dstock_canon.cli import main
from dstock_canon.reconcile import PROMOTION_STREAK, EligibilityLedger
from dstock_canon.tests.helpers import price_row


def _run(argv):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = main(argv)
    return code, out.getvalue(), err.getvalue()


class CliFlowTests(unittest.TestCase):
    def setUp(self):
        self._folder = tempfile.TemporaryDirectory()
        self.addCleanup(self._folder.cleanup)
        self.folder = self._folder.name
        self.primary_rows = os.path.join(self.folder, "primary.jsonl")
        self.backup_rows = os.path.join(self.folder, "backup.jsonl")
        write_rows(self.primary_rows, [price_row("2330"), price_row("2317", close=210)])
        write_rows(self.backup_rows, [
            price_row("2330", source_id="finmind_collect", source_class="backup"),
            price_row("2317", close=210, source_id="finmind_collect", source_class="backup"),
        ])

    def _build_receipt(self, rows_path, source_id, source_class, output):
        return _run([
            "build-receipt", "--source-id", source_id, "--source-class", source_class,
            "--asof", "2026-09-03", "--generated-at", "2026-09-03T15:05:00+08:00",
            "--rows", f"daily_price={rows_path}", "--expected", "daily_price=2",
            "--code-version", "cli-test", "--config-hash", "deadbeef", "-o", output,
        ])

    def test_stdout_is_parseable_json_with_messages_on_stderr(self):
        code, out, err = _run(["validate-rows", self.primary_rows])
        self.assertEqual(code, 0)
        payload = json.loads(out)
        self.assertEqual(payload["rows"], {"daily_price": 2})
        self.assertEqual(err, "")

    def test_full_failover_flow(self):
        primary_receipt = os.path.join(self.folder, "primary_receipt.json")
        backup_receipt = os.path.join(self.folder, "backup_receipt.json")
        ledger_path = os.path.join(self.folder, "ledger.json")

        code, out, _ = self._build_receipt(self.primary_rows, "market_update", "primary", primary_receipt)
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["publishability"], "publishable")

        code, out, _ = self._build_receipt(self.backup_rows, "finmind_collect", "backup", backup_receipt)
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["publishability"], "degraded")

        for day in range(1, PROMOTION_STREAK + 1):
            code, out, _ = _run([
                "compare", "--trading-day", f"2026-08-{day:02d}",
                "--primary", f"daily_price={self.primary_rows}",
                "--backup", f"daily_price={self.backup_rows}",
                "--ledger", ledger_path,
            ])
            self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["eligible_datasets"], ["daily_price"])
        self.assertTrue(EligibilityLedger.load(ledger_path).eligible("daily_price"))

        manifest_path = os.path.join(self.folder, "manifest.json")
        code, out, _ = _run([
            "promote", "--required", "daily_price",
            "--primary-receipt", primary_receipt, "--backup-receipt", backup_receipt,
            "--ledger", ledger_path, "--asof", "2026-09-03",
            "--generated-at", "2026-09-03T15:10:00+08:00", "-o", manifest_path,
        ])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["decision"]["degradation_level"], "L0")

        code, out, _ = _run([
            "promote", "--required", "daily_price", "--backup-receipt", backup_receipt,
            "--ledger", ledger_path, "--asof", "2026-09-03",
            "--generated-at", "2026-09-03T15:10:00+08:00",
        ])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["manifest"]["degradation_level"], "L1")

    def test_no_receipt_at_all_is_an_error(self):
        code, _, err = _run([
            "promote", "--required", "daily_price", "--asof", "2026-09-03",
            "--generated-at", "2026-09-03T15:10:00+08:00",
        ])
        self.assertEqual(code, 2)
        self.assertIn("receipt", err)

    def test_l3_exits_with_its_own_code(self):
        """A receipt exists but nothing covers the dataset: blocked, not an error."""
        backup_receipt = os.path.join(self.folder, "backup_receipt.json")
        self._build_receipt(self.backup_rows, "finmind_collect", "backup", backup_receipt)
        code, out, _ = _run([
            "promote", "--required", "daily_price", "--backup-receipt", backup_receipt,
            "--asof", "2026-09-03", "--generated-at", "2026-09-03T15:10:00+08:00",
        ])
        self.assertEqual(code, 3)
        self.assertEqual(json.loads(out)["manifest"]["publishability"], "blocked")

    def test_a_tampered_row_file_fails_the_command(self):
        bad = os.path.join(self.folder, "bad.jsonl")
        with open(self.primary_rows, encoding="utf-8") as handle:
            row = json.loads(handle.readline())
        row["values"]["close"] = 1
        with open(bad, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(row) + "\n")
        code, _, err = _run(["validate-rows", bad])
        self.assertEqual(code, 2)
        self.assertIn("value_hash", err)

    def test_unregistered_dataset_is_refused(self):
        with self.assertRaises(SystemExit):
            _run(["validate-rows", self.primary_rows] and
                 ["compare", "--trading-day", "2026-09-03", "--primary", "not_a_table=x"])


if __name__ == "__main__":
    unittest.main()
