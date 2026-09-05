"""Receipts are derived from rows, so a source cannot claim unearned eligibility."""

from __future__ import annotations

import unittest

from dstock_canon.receipt import (
    ReceiptError,
    build_receipt,
    failed_receipt,
    is_stale,
    summarize_dataset,
    validate_receipt,
)
from dstock_canon.tests.helpers import price_row

EVIDENCE = {"code_version": "test-1.0.0", "config_hash": "abc123"}


def _build(rows, expected, **kwargs):
    params = dict(
        source_id="market_update",
        source_class="primary",
        asof="2026-09-03",
        expected_asof="2026-09-03",
        generated_at="2026-09-03T15:05:00+08:00",
        rows_by_dataset={"daily_price": rows},
        expected_rows={"daily_price": expected},
        evidence=EVIDENCE,
    )
    params.update(kwargs)
    return build_receipt(**params)


class SummaryTests(unittest.TestCase):
    def test_coverage_counts_only_usable_rows(self):
        rows = [price_row("2330"), price_row("2317", close=210), price_row("6488", close=95, market="unknown")]
        block = summarize_dataset("daily_price", rows, expected_rows=3, asof="2026-09-03")
        self.assertEqual(block["actual_rows"], 3)
        self.assertEqual(block["quarantined_rows"], 1)
        self.assertAlmostEqual(block["coverage_to_cutoff"], 2 / 3)
        self.assertEqual(block["missing_rows"], 1)

    def test_future_rows_are_excluded_and_counted(self):
        rows = [price_row("2330"), price_row("2317", row_date="2026-09-04",
                                             availability_time="2026-09-04T14:30:00+08:00")]
        block = summarize_dataset("daily_price", rows, expected_rows=1, asof="2026-09-03")
        self.assertEqual(block["future_row_count"], 1)
        self.assertEqual(block["coverage_to_cutoff"], 1.0)

    def test_duplicate_row_keys_are_rejected(self):
        with self.assertRaises(ReceiptError):
            summarize_dataset("daily_price", [price_row("2330"), price_row("2330")],
                              expected_rows=1, asof="2026-09-03")

    def test_denominator_cannot_be_backfilled_from_actual_rows(self):
        with self.assertRaises(ReceiptError):
            summarize_dataset("daily_price", [price_row("2330")], expected_rows=0, asof="2026-09-03")

    def test_rollup_ignores_quarantined_rows(self):
        clean = summarize_dataset("daily_price", [price_row("2330")], expected_rows=1, asof="2026-09-03")
        withheld = summarize_dataset(
            "daily_price",
            [price_row("2330"), price_row("6488", close=95, market="unknown")],
            expected_rows=1,
            asof="2026-09-03",
        )
        self.assertEqual(clean["value_hash"], withheld["value_hash"])


class PublishabilityTests(unittest.TestCase):
    def test_complete_primary_is_publishable(self):
        receipt = _build([price_row("2330")], 1)
        self.assertEqual(receipt["status"], "complete")
        self.assertEqual(receipt["publishability"], "publishable")

    def test_backup_is_never_more_than_degraded(self):
        receipt = _build(
            [price_row("2330", source_id="finmind_collect", source_class="backup")],
            1,
            source_id="finmind_collect",
            source_class="backup",
        )
        self.assertEqual(receipt["status"], "complete")
        self.assertEqual(receipt["publishability"], "degraded")

    def test_future_rows_block_publication(self):
        rows = [price_row("2330"), price_row("2317", row_date="2026-09-04",
                                             availability_time="2026-09-04T14:30:00+08:00")]
        self.assertEqual(_build(rows, 1)["publishability"], "blocked")

    def test_unknown_availability_blocks_publication(self):
        rows = [price_row("2330"), price_row("2317", availability_basis="unknown", availability_time=None)]
        receipt = _build(rows, 1)
        self.assertEqual(receipt["pit"]["unknown_availability_rows"], 1)
        self.assertEqual(receipt["publishability"], "blocked")

    def test_partial_coverage_is_degraded_not_publishable(self):
        receipt = _build([price_row("2330")], 5)
        self.assertEqual(receipt["status"], "partial")
        self.assertEqual(receipt["publishability"], "degraded")

    def test_reference_only_can_never_publish(self):
        rows = [price_row("2330", source_id="mitake_ui", source_class="reference_only")]
        receipt = _build(rows, 1, source_id="mitake_ui", source_class="reference_only")
        self.assertEqual(receipt["publishability"], "blocked")

    def test_rows_from_another_source_are_rejected(self):
        with self.assertRaises(ReceiptError):
            _build([price_row("2330", source_id="finmind_collect", source_class="backup")], 1)


class FailureAndStalenessTests(unittest.TestCase):
    def test_failed_receipt_is_blocked_and_carries_a_reason(self):
        receipt = failed_receipt(
            source_id="market_update", source_class="primary",
            asof="2026-09-03", expected_asof="2026-09-03",
            generated_at="2026-09-03T15:05:00+08:00",
            reason_code="source_unreachable", detail="連線逾時", evidence=EVIDENCE,
        )
        self.assertEqual(receipt["status"], "failed")
        self.assertEqual(receipt["publishability"], "blocked")
        self.assertEqual(receipt["failure"]["reason_code"], "source_unreachable")

    def test_unregistered_failure_reason_is_rejected(self):
        with self.assertRaises(ReceiptError):
            failed_receipt(
                source_id="market_update", source_class="primary",
                asof="2026-09-03", expected_asof="2026-09-03",
                generated_at="2026-09-03T15:05:00+08:00",
                reason_code="just_because", detail="", evidence=EVIDENCE,
            )

    def test_stale_asof_is_detected(self):
        receipt = _build([price_row("2330", row_date="2026-09-02",
                                    availability_time="2026-09-02T14:30:00+08:00")], 1,
                         asof="2026-09-02", expected_asof="2026-09-03")
        self.assertTrue(is_stale(receipt))
        self.assertFalse(is_stale(_build([price_row("2330")], 1)))

    def test_asof_after_expected_asof_is_rejected(self):
        receipt = _build([price_row("2330")], 1)
        receipt["asof"] = "2026-09-05"
        with self.assertRaises(ReceiptError):
            validate_receipt(receipt)

    def test_publishable_cannot_be_asserted_on_a_backup(self):
        receipt = _build(
            [price_row("2330", source_id="finmind_collect", source_class="backup")],
            1, source_id="finmind_collect", source_class="backup",
        )
        receipt["publishability"] = "publishable"
        with self.assertRaises(ReceiptError):
            validate_receipt(receipt)

    def test_missing_evidence_is_rejected(self):
        with self.assertRaises(ReceiptError):
            _build([price_row("2330")], 1, evidence={"code_version": "x"})


if __name__ == "__main__":
    unittest.main()
