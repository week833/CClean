"""Backup eligibility is earned by measurement over consecutive trading days."""

from __future__ import annotations

import unittest

from dstock_canon.reconcile import (
    BAND_BREACH,
    BAND_NO_EVIDENCE,
    BAND_QUALIFYING,
    BAND_WARNING,
    PROMOTION_STREAK,
    EligibilityLedger,
    classify,
    compare_dataset,
)
from dstock_canon.tests.helpers import price_row


def _pair(stock_id, close_primary, close_backup):
    return (
        price_row(stock_id, close=close_primary),
        price_row(stock_id, close=close_backup, source_id="finmind_collect", source_class="backup"),
    )


def _comparison(match_rate, key_only_in_backup=0, compared=1000):
    matched = None if match_rate is None else round(match_rate * compared)
    return {
        "dataset": "daily_price",
        "compared_rows": compared if match_rate is not None else 0,
        "match_rows": matched or 0,
        "match_rate": match_rate,
        "key_only_in_primary": 0,
        "key_only_in_backup": key_only_in_backup,
        "mismatched_keys": [],
    }


class CompareTests(unittest.TestCase):
    def test_identical_rows_match_completely(self):
        primary, backup = zip(*[_pair("2330", 584, 584), _pair("2317", 210, 210)])
        result = compare_dataset("daily_price", list(primary), list(backup))
        self.assertEqual(result["compared_rows"], 2)
        self.assertEqual(result["match_rate"], 1.0)

    def test_a_value_difference_is_visible(self):
        primary, backup = zip(*[_pair("2330", 584, 584), _pair("2317", 210, 211)])
        result = compare_dataset("daily_price", list(primary), list(backup))
        self.assertEqual(result["match_rows"], 1)
        self.assertEqual(result["match_rate"], 0.5)
        self.assertEqual(result["mismatched_keys"], ["2317|2026-09-03"])

    def test_quarantined_rows_do_not_participate(self):
        primary = [price_row("2330")]
        backup = [
            price_row("2330", source_id="finmind_collect", source_class="backup"),
            price_row("6488", close=95, market="unknown", source_id="finmind_collect", source_class="backup"),
        ]
        result = compare_dataset("daily_price", primary, backup)
        self.assertEqual(result["compared_rows"], 1)
        self.assertEqual(result["key_only_in_backup"], 0)

    def test_phantom_backup_rows_are_reported(self):
        primary = [price_row("2330")]
        backup = [
            price_row("2330", source_id="finmind_collect", source_class="backup"),
            price_row("9999", close=1, source_id="finmind_collect", source_class="backup"),
        ]
        self.assertEqual(compare_dataset("daily_price", primary, backup)["key_only_in_backup"], 1)

    def test_no_overlap_yields_no_evidence(self):
        result = compare_dataset("daily_price", [price_row("2330")], [])
        self.assertIsNone(result["match_rate"])
        self.assertEqual(classify(result), BAND_NO_EVIDENCE)


class BandTests(unittest.TestCase):
    def test_bands_follow_the_declared_thresholds(self):
        self.assertEqual(classify(_comparison(1.0)), BAND_QUALIFYING)
        self.assertEqual(classify(_comparison(0.999)), BAND_QUALIFYING)
        self.assertEqual(classify(_comparison(0.995)), BAND_WARNING)
        self.assertEqual(classify(_comparison(0.99)), BAND_WARNING)
        self.assertEqual(classify(_comparison(0.98)), BAND_BREACH)

    def test_phantom_rows_are_a_breach_even_at_a_perfect_rate(self):
        self.assertEqual(classify(_comparison(1.0, key_only_in_backup=1)), BAND_BREACH)


class LedgerTests(unittest.TestCase):
    def _run(self, ledger, rates, start=1):
        for offset, rate in enumerate(rates, start=start):
            ledger.record(f"2026-09-{offset:02d}", _comparison(rate))

    def test_promotion_requires_the_full_streak(self):
        ledger = EligibilityLedger()
        self._run(ledger, [1.0] * (PROMOTION_STREAK - 1))
        self.assertFalse(ledger.eligible("daily_price"))
        self.assertEqual(ledger.streak("daily_price"), PROMOTION_STREAK - 1)
        self._run(ledger, [1.0])
        self.assertTrue(ledger.eligible("daily_price"))

    def test_a_warning_day_resets_the_streak_without_demoting(self):
        ledger = EligibilityLedger()
        self._run(ledger, [1.0] * PROMOTION_STREAK)
        self.assertTrue(ledger.eligible("daily_price"))
        ledger.record("2026-10-01", _comparison(0.995))
        self.assertEqual(ledger.streak("daily_price"), 0)
        self.assertTrue(ledger.eligible("daily_price"))

    def test_a_breach_demotes_immediately(self):
        ledger = EligibilityLedger()
        self._run(ledger, [1.0] * PROMOTION_STREAK)
        ledger.record("2026-10-01", _comparison(0.5))
        self.assertFalse(ledger.eligible("daily_price"))
        self.assertEqual(ledger.streak("daily_price"), 0)

    def test_recovery_needs_the_full_streak_again(self):
        ledger = EligibilityLedger()
        self._run(ledger, [1.0] * PROMOTION_STREAK)
        ledger.record("2026-10-01", _comparison(0.5))
        self._run(ledger, [1.0] * (PROMOTION_STREAK - 1), start=2)
        self.assertFalse(ledger.eligible("daily_price"))
        ledger.record("2026-11-01", _comparison(1.0))
        self.assertTrue(ledger.eligible("daily_price"))

    def test_no_evidence_neither_advances_nor_demotes(self):
        ledger = EligibilityLedger()
        self._run(ledger, [1.0] * PROMOTION_STREAK)
        ledger.record("2026-10-01", _comparison(None))
        self.assertTrue(ledger.eligible("daily_price"))
        self.assertEqual(ledger.streak("daily_price"), PROMOTION_STREAK)

    def test_eligibility_is_tracked_per_dataset(self):
        ledger = EligibilityLedger()
        self._run(ledger, [1.0] * PROMOTION_STREAK)
        for day in range(1, PROMOTION_STREAK + 1):
            ledger.record(f"2026-09-{day:02d}", {**_comparison(0.5), "dataset": "broker_branch"})
        self.assertEqual(ledger.eligible_datasets(), ("daily_price",))

    def test_state_survives_a_round_trip(self):
        ledger = EligibilityLedger()
        self._run(ledger, [1.0] * PROMOTION_STREAK)
        restored = EligibilityLedger(ledger.to_dict())
        self.assertTrue(restored.eligible("daily_price"))
        self.assertEqual(restored.streak("daily_price"), PROMOTION_STREAK)


if __name__ == "__main__":
    unittest.main()
