"""The promotion gate, including the four acceptance drills from the plan."""

from __future__ import annotations

import unittest

from dstock_canon.promotion import (
    PromotionError,
    build_manifest,
    decide,
    merge_rows,
    plan_restatements,
    validate_manifest,
)
from dstock_canon.governance import Governance
from dstock_canon.receipt import build_receipt, failed_receipt
from dstock_canon.tests.helpers import price_row, revenue_row

EVIDENCE = {"code_version": "test-1.0.0", "config_hash": "abc123"}

#: Stands in for an adopted ADR-0002. Tests that exercise substitution must
#: pass it explicitly; the production default ratifies primary only.
RATIFIED = Governance(
    ratified_classes=frozenset({"primary", "backup"}),
    adr="ADR-0002",
    ratified_at="2026-09-10",
)


def _decide(**kwargs):
    """decide() under an adopted ADR-0002 unless a test says otherwise."""
    kwargs.setdefault("governance", RATIFIED)
    return decide(**kwargs)
ASOF = "2026-09-03"
NOW = "2026-09-03T15:05:00+08:00"


def _receipt(source_id, source_class, rows_by_dataset, expected_rows):
    return build_receipt(
        source_id=source_id, source_class=source_class, asof=ASOF, expected_asof=ASOF,
        generated_at=NOW, rows_by_dataset=rows_by_dataset, expected_rows=expected_rows,
        evidence=EVIDENCE,
    )


def _primary(datasets=("daily_price",), stock_ids=("2330",)):
    rows = {"daily_price": [price_row(sid) for sid in stock_ids]}
    if "month_revenue" in datasets:
        rows["month_revenue"] = [
            dict(revenue_row(sid), source_id="market_update", source_class="primary") for sid in stock_ids
        ]
    rows = {name: value for name, value in rows.items() if name in datasets}
    return _receipt("market_update", "primary", rows, {name: len(stock_ids) for name in rows})


def _backup(datasets=("daily_price",), stock_ids=("2330",)):
    rows = {"daily_price": [
        price_row(sid, source_id="finmind_collect", source_class="backup") for sid in stock_ids
    ]}
    if "month_revenue" in datasets:
        rows["month_revenue"] = [revenue_row(sid) for sid in stock_ids]
    rows = {name: value for name, value in rows.items() if name in datasets}
    return _receipt("finmind_collect", "backup", rows, {name: len(stock_ids) for name in rows})


class AcceptanceDrillTests(unittest.TestCase):
    """The four drills the plan requires before this is trusted."""

    def test_drill_normal_day_is_l0(self):
        result = _decide(
            required_datasets=["daily_price"],
            primary_receipt=_primary(), backup_receipt=_backup(),
            eligible_datasets=["daily_price"],
        )
        self.assertEqual(result["degradation_level"], "L0")
        self.assertEqual(result["effective_source"], "market_update")

    def test_drill_primary_down_is_l1(self):
        failed = failed_receipt(
            source_id="market_update", source_class="primary", asof=ASOF, expected_asof=ASOF,
            generated_at=NOW, reason_code="source_unreachable", detail="連線逾時", evidence=EVIDENCE,
        )
        result = _decide(
            required_datasets=["daily_price"],
            primary_receipt=failed, backup_receipt=_backup(),
            eligible_datasets=["daily_price"],
        )
        self.assertEqual(result["degradation_level"], "L1")
        self.assertEqual(result["effective_source"], "finmind_collect")

    def test_drill_backup_down_does_not_disturb_l0(self):
        failed = failed_receipt(
            source_id="finmind_collect", source_class="backup", asof=ASOF, expected_asof=ASOF,
            generated_at=NOW, reason_code="quota_exceeded", detail="超過配額", evidence=EVIDENCE,
        )
        result = _decide(
            required_datasets=["daily_price"],
            primary_receipt=_primary(), backup_receipt=failed,
            eligible_datasets=["daily_price"],
        )
        self.assertEqual(result["degradation_level"], "L0")

    def test_drill_both_down_is_l3_not_an_empty_publication(self):
        result = _decide(
            required_datasets=["daily_price"],
            primary_receipt=None, backup_receipt=None, eligible_datasets=[],
        )
        self.assertEqual(result["degradation_level"], "L3")
        self.assertEqual(result["uncovered_datasets"], ["daily_price"])

    def test_drill_bad_backup_data_is_refused(self):
        """An ineligible dataset cannot fill a gap even when it looks complete."""
        result = _decide(
            required_datasets=["daily_price"],
            primary_receipt=None, backup_receipt=_backup(), eligible_datasets=[],
        )
        self.assertEqual(result["degradation_level"], "L3")
        self.assertEqual(result["ineligible_datasets"], ["daily_price"])


class LevelTests(unittest.TestCase):
    def test_partial_primary_plus_eligible_backup_is_l2(self):
        result = _decide(
            required_datasets=["daily_price", "month_revenue"],
            primary_receipt=_primary(datasets=("daily_price",)),
            backup_receipt=_backup(datasets=("daily_price", "month_revenue")),
            eligible_datasets=["daily_price", "month_revenue"],
        )
        self.assertEqual(result["degradation_level"], "L2")
        self.assertEqual(result["effective_source"], "mixed")
        self.assertEqual(result["assignment"]["daily_price"], "market_update")
        self.assertEqual(result["assignment"]["month_revenue"], "finmind_collect")

    def test_a_gap_neither_source_covers_is_l3(self):
        result = _decide(
            required_datasets=["daily_price", "month_revenue"],
            primary_receipt=_primary(datasets=("daily_price",)),
            backup_receipt=_backup(datasets=("daily_price",)),
            eligible_datasets=["daily_price"],
        )
        self.assertEqual(result["degradation_level"], "L3")
        self.assertEqual(result["uncovered_datasets"], ["month_revenue"])

    def test_unclean_pit_removes_the_primary_from_l0(self):
        rows = [price_row("2330"), price_row("2317", availability_basis="unknown", availability_time=None)]
        dirty = _receipt("market_update", "primary", {"daily_price": rows}, {"daily_price": 1})
        result = _decide(
            required_datasets=["daily_price"], primary_receipt=dirty,
            backup_receipt=_backup(), eligible_datasets=["daily_price"],
        )
        self.assertEqual(result["degradation_level"], "L1")

    def test_a_backup_receipt_cannot_be_passed_as_primary(self):
        with self.assertRaises(PromotionError):
            _decide(required_datasets=["daily_price"], primary_receipt=_backup(),
                   backup_receipt=None, eligible_datasets=[])

    def test_empty_required_set_is_rejected(self):
        with self.assertRaises(PromotionError):
            _decide(required_datasets=[], primary_receipt=_primary(),
                   backup_receipt=None, eligible_datasets=[])


class PrecedenceTests(unittest.TestCase):
    def test_primary_wins_over_backup_on_the_same_key(self):
        rows = [
            price_row("2330", close=584),
            price_row("2330", close=999, source_id="finmind_collect", source_class="backup"),
        ]
        merged = merge_rows(rows)
        self.assertEqual(len(merged["rows"]), 1)
        self.assertEqual(merged["rows"][0]["source_id"], "market_update")
        self.assertEqual(merged["conflicts"], [])

    def test_better_availability_evidence_wins_within_a_class(self):
        rows = [
            price_row("2330", close=584, source_id="finmind_collect", source_class="backup",
                      availability_basis="announced"),
            price_row("2330", close=999, source_id="mitake_ui", source_class="backup",
                      availability_basis="conservative_lag"),
        ]
        merged = merge_rows(rows)
        self.assertEqual(merged["rows"][0]["availability_basis"], "announced")

    def test_an_unbreakable_tie_becomes_a_quarantined_conflict(self):
        rows = [
            price_row("2330", close=584, source_id="market_update", source_class="primary"),
            price_row("2330", close=999, source_id="finmind_collect", source_class="primary"),
        ]
        merged = merge_rows(rows)
        self.assertEqual(len(merged["conflicts"]), 1)
        self.assertTrue(merged["rows"][0]["quarantined"])

    def test_reference_only_rows_never_enter_the_merge(self):
        rows = [price_row("2330", source_id="mitake_ui", source_class="reference_only")]
        self.assertEqual(merge_rows(rows)["rows"], [])

    def test_agreeing_sources_produce_no_conflict(self):
        rows = [
            price_row("2330", close=584),
            price_row("2330", close=584, source_id="finmind_collect", source_class="backup"),
        ]
        self.assertEqual(merge_rows(rows)["conflicts"], [])


class RestatementTests(unittest.TestCase):
    def test_a_recovered_primary_records_what_it_overwrites(self):
        held = [price_row("2330", close=999, source_id="finmind_collect", source_class="backup")]
        recovered = [price_row("2330", close=584)]
        records = plan_restatements(held, recovered, restated_at=NOW)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["from_source"], "finmind_collect")
        self.assertEqual(records[0]["to_source"], "market_update")

    def test_agreement_needs_no_restatement(self):
        held = [price_row("2330", close=584, source_id="finmind_collect", source_class="backup")]
        recovered = [price_row("2330", close=584)]
        self.assertEqual(plan_restatements(held, recovered, restated_at=NOW), [])


class ManifestTests(unittest.TestCase):
    def _manifest(self, level_inputs):
        result = _decide(**level_inputs)
        return build_manifest(
            asof=ASOF, expected_asof=ASOF, generated_at=NOW, decision=result,
            primary_receipt=level_inputs["primary_receipt"],
            backup_receipt=level_inputs["backup_receipt"],
        )

    def test_l1_manifest_is_degraded_and_names_the_backup(self):
        failed = failed_receipt(
            source_id="market_update", source_class="primary", asof=ASOF, expected_asof=ASOF,
            generated_at=NOW, reason_code="source_unreachable", detail="連線逾時", evidence=EVIDENCE,
        )
        manifest = self._manifest({
            "required_datasets": ["daily_price"], "primary_receipt": failed,
            "backup_receipt": _backup(), "eligible_datasets": ["daily_price"],
        })
        self.assertEqual(manifest["degradation_level"], "L1")
        self.assertEqual(manifest["publishability"], "degraded")
        self.assertEqual(manifest["effective_source"], "finmind_collect")
        self.assertEqual({s["source_id"] for s in manifest["sources"]}, {"market_update", "finmind_collect"})

    def test_level_and_publishability_cannot_disagree(self):
        manifest = self._manifest({
            "required_datasets": ["daily_price"], "primary_receipt": _primary(),
            "backup_receipt": _backup(), "eligible_datasets": ["daily_price"],
        })
        manifest["degradation_level"] = "L3"
        with self.assertRaises(PromotionError):
            validate_manifest(manifest)

    def test_a_manifest_needs_at_least_one_receipt(self):
        with self.assertRaises(PromotionError):
            build_manifest(
                asof=ASOF, expected_asof=ASOF, generated_at=NOW,
                decision={"degradation_level": "L3", "effective_source": "none"},
                primary_receipt=None, backup_receipt=None,
            )


class GovernanceGateTests(unittest.TestCase):
    """A measured-good backup still cannot substitute until an ADR authorises it."""

    def _inputs(self):
        failed = failed_receipt(
            source_id="market_update", source_class="primary", asof=ASOF, expected_asof=ASOF,
            generated_at=NOW, reason_code="source_unreachable", detail="連線逾時", evidence=EVIDENCE,
        )
        return {
            "required_datasets": ["daily_price"],
            "primary_receipt": failed,
            "backup_receipt": _backup(),
            "eligible_datasets": ["daily_price"],
        }

    def test_default_governance_withholds_the_backup(self):
        result = decide(**self._inputs())
        self.assertEqual(result["degradation_level"], "L3")
        self.assertEqual(result["governance_withheld"], ["daily_price"])
        self.assertEqual(result["governance"]["ratified_classes"], ["primary"])

    def test_the_reason_is_stated_not_silent(self):
        result = decide(**self._inputs())
        self.assertIn("backup", result["governance_note"])
        self.assertIn("ADR-0001", result["governance_note"])

    def test_an_adopted_adr_lets_the_same_inputs_through(self):
        result = decide(**self._inputs(), governance=RATIFIED)
        self.assertEqual(result["degradation_level"], "L1")
        self.assertEqual(result["governance_withheld"], [])
        self.assertEqual(result["governance"]["adr"], "ADR-0002")

    def test_a_populated_eligible_list_cannot_bypass_the_gate(self):
        """The pre-ADR safety property no longer depends on the caller."""
        inputs = self._inputs()
        inputs["eligible_datasets"] = ["daily_price", "month_revenue", "broker_branch"]
        self.assertEqual(decide(**inputs)["degradation_level"], "L3")

    def test_primary_is_unaffected_by_the_gate(self):
        result = decide(
            required_datasets=["daily_price"], primary_receipt=_primary(),
            backup_receipt=_backup(), eligible_datasets=["daily_price"],
        )
        self.assertEqual(result["degradation_level"], "L0")
        self.assertEqual(result["governance_withheld"], [])

    def test_manifest_carries_the_blocked_outcome(self):
        result = decide(**self._inputs())
        manifest = build_manifest(
            asof=ASOF, expected_asof=ASOF, generated_at=NOW, decision=result,
            primary_receipt=self._inputs()["primary_receipt"], backup_receipt=_backup(),
        )
        self.assertEqual(manifest["publishability"], "blocked")


if __name__ == "__main__":
    unittest.main()
