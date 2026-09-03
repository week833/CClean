"""Canonical rows must fail closed rather than publish an unproven fact."""

from __future__ import annotations

import json
import os
import tempfile
import unittest

from dstock_canon.canonical import CanonicalError, build_row, build_row_key, read_rows, validate_row, write_rows
from dstock_canon.dataset_spec import get_spec
from dstock_canon.tests.helpers import price_row, revenue_row


class RowKeyTests(unittest.TestCase):
    def test_key_follows_the_declared_order(self):
        spec = get_spec("daily_price")
        self.assertEqual(build_row_key(spec, {"date": "2026-09-03", "stock_id": "2330"}), "2330|2026-09-03")

    def test_missing_and_extra_key_fields_are_rejected(self):
        spec = get_spec("daily_price")
        with self.assertRaises(CanonicalError):
            build_row_key(spec, {"stock_id": "2330"})
        with self.assertRaises(CanonicalError):
            build_row_key(spec, {"stock_id": "2330", "date": "2026-09-03", "extra": 1})

    def test_separator_inside_a_key_value_is_rejected(self):
        spec = get_spec("daily_price")
        with self.assertRaises(CanonicalError):
            build_row_key(spec, {"stock_id": "23|30", "date": "2026-09-03"})

    def test_empty_key_value_is_rejected(self):
        spec = get_spec("daily_price")
        with self.assertRaises(CanonicalError):
            build_row_key(spec, {"stock_id": "  ", "date": "2026-09-03"})


class FailClosedTests(unittest.TestCase):
    def test_unknown_availability_forces_quarantine(self):
        row = price_row(availability_basis="unknown", availability_time=None)
        self.assertTrue(row["quarantined"])

    def test_unknown_unit_forces_quarantine_and_flags_it(self):
        row = price_row(unit_basis="unknown")
        self.assertTrue(row["quarantined"])
        self.assertIn("unit_unconvertible", row["quality_flags"])

    def test_unknown_market_forces_quarantine(self):
        self.assertTrue(price_row(market="unknown")["quarantined"])

    def test_a_row_cannot_claim_clean_status_with_unknown_envelope(self):
        row = price_row(market="unknown")
        row["quarantined"] = False
        with self.assertRaises(CanonicalError):
            validate_row(row)

    def test_adjusted_price_requires_a_frozen_snapshot(self):
        with self.assertRaises(CanonicalError):
            price_row(price_basis="adjusted")
        row = price_row(price_basis="adjusted", adj_snapshot_id="adj-2026-09-03-a")
        self.assertEqual(row["adj_snapshot_id"], "adj-2026-09-03-a")

    def test_snapshot_id_is_rejected_on_raw_prices(self):
        row = price_row()
        row["adj_snapshot_id"] = "adj-1"
        with self.assertRaises(CanonicalError):
            validate_row(row)

    def test_value_hash_cannot_be_asserted(self):
        row = price_row()
        row["value_hash"] = "0" * 64
        with self.assertRaises(CanonicalError):
            validate_row(row)

    def test_values_cannot_change_without_the_hash(self):
        row = price_row()
        row["values"]["close"] = 999
        with self.assertRaises(CanonicalError):
            validate_row(row)

    def test_availability_time_must_not_precede_row_date(self):
        with self.assertRaises(CanonicalError):
            price_row(availability_time="2026-09-01T09:00:00+08:00")

    def test_null_availability_time_requires_unknown_basis(self):
        with self.assertRaises(CanonicalError):
            price_row(availability_time=None)


class DatasetShapeTests(unittest.TestCase):
    def test_dataset_without_market_must_use_not_applicable(self):
        row = revenue_row()
        self.assertEqual(row["market"], "not_applicable")
        row["market"] = "twse"
        with self.assertRaises(CanonicalError):
            validate_row(row)

    def test_price_dataset_must_declare_a_price_basis(self):
        with self.assertRaises(CanonicalError):
            price_row(price_basis="not_applicable")

    def test_unknown_quality_flag_is_rejected(self):
        row = price_row()
        row["quality_flags"] = ["invented_flag"]
        with self.assertRaises(CanonicalError):
            validate_row(row)

    def test_unknown_envelope_field_is_rejected(self):
        row = price_row()
        row["extra"] = 1
        with self.assertRaises(CanonicalError):
            validate_row(row)


class RoundTripTests(unittest.TestCase):
    def test_rows_survive_a_write_and_read(self):
        rows = [price_row("2330"), price_row("2317", close=210)]
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "rows.jsonl")
            self.assertEqual(write_rows(path, rows), 2)
            restored = list(read_rows(path))
        self.assertEqual([row["row_key"] for row in restored], ["2330|2026-09-03", "2317|2026-09-03"])

    def test_a_tampered_file_is_rejected_on_read(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "rows.jsonl")
            write_rows(path, [price_row()])
            with open(path, encoding="utf-8") as handle:
                row = json.loads(handle.read())
            row["values"]["close"] = 1
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(json.dumps(row) + "\n")
            with self.assertRaises(CanonicalError):
                list(read_rows(path))


if __name__ == "__main__":
    unittest.main()
