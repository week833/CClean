"""The shared hash must be insensitive to encoding and sensitive to content."""

from __future__ import annotations

import unittest

from dstock_canon.dataset_spec import FieldSpec, SpecError
from dstock_canon.value_hash import canonical_payload, normalize_field, rollup_hash, value_hash


class NormalizationTests(unittest.TestCase):
    def test_equivalent_encodings_hash_equal(self):
        a = {"revenue": 1234567, "currency": "TWD"}
        b = {"revenue": "1234567", "currency": " TWD "}
        self.assertEqual(value_hash("month_revenue", a), value_hash("month_revenue", b))

    def test_trailing_zeros_do_not_change_the_hash(self):
        spec = FieldSpec("close", "decimal", 4)
        self.assertEqual(normalize_field("584.0000", spec), "584")
        self.assertEqual(normalize_field(584, spec), "584")
        self.assertEqual(normalize_field("584.00", spec), "584")

    def test_missing_is_not_zero(self):
        spec = FieldSpec("limit_up", "decimal", 4)
        self.assertEqual(normalize_field(None, spec), "")
        self.assertEqual(normalize_field("", spec), "")
        self.assertNotEqual(normalize_field(None, spec), normalize_field(0, spec))

    def test_negative_zero_folds_to_zero(self):
        spec = FieldSpec("change", "decimal", 4)
        self.assertEqual(normalize_field("-0.00001", spec), "0")
        self.assertEqual(normalize_field("-0.0", spec), "0")

    def test_half_up_rounding_at_the_declared_place(self):
        spec = FieldSpec("foreign_ratio", "decimal", 6)
        self.assertEqual(normalize_field("0.12345650", spec), "0.123457")
        self.assertEqual(normalize_field("0.12345644", spec), "0.123456")

    def test_difference_below_the_declared_place_is_invisible(self):
        spec = FieldSpec("close", "decimal", 4)
        self.assertEqual(normalize_field("584.00001", spec), normalize_field("584.00002", spec))

    def test_difference_at_the_declared_place_is_visible(self):
        a = {"revenue": 1, "currency": "TWD"}
        b = {"revenue": 2, "currency": "TWD"}
        self.assertNotEqual(value_hash("month_revenue", a), value_hash("month_revenue", b))

    def test_integer_field_rejects_fractions_and_booleans(self):
        spec = FieldSpec("volume_shares", "integer")
        with self.assertRaises(ValueError):
            normalize_field(1.5, spec)
        with self.assertRaises(ValueError):
            normalize_field(True, spec)

    def test_non_finite_is_rejected(self):
        spec = FieldSpec("close", "decimal", 4)
        with self.assertRaises(ValueError):
            normalize_field(float("inf"), spec)
        self.assertEqual(normalize_field(float("nan"), spec), "")

    def test_fields_outside_the_whitelist_are_rejected(self):
        with self.assertRaises(SpecError):
            value_hash("month_revenue", {"revenue": 1, "currency": "TWD", "sneaky": 9})

    def test_payload_is_sorted_by_field_name(self):
        payload = canonical_payload("month_revenue", {"revenue": 1, "currency": "TWD"})
        self.assertEqual(payload, "currency=TWD\nrevenue=1")


class RollupTests(unittest.TestCase):
    def test_rollup_is_independent_of_insertion_order(self):
        forward = rollup_hash({"a|1": "x" * 64, "b|2": "y" * 64})
        backward = rollup_hash({"b|2": "y" * 64, "a|1": "x" * 64})
        self.assertEqual(forward, backward)

    def test_rollup_changes_when_a_row_changes(self):
        base = rollup_hash({"a|1": "x" * 64})
        changed = rollup_hash({"a|1": "z" * 64})
        self.assertNotEqual(base, changed)

    def test_rollup_changes_when_a_row_is_dropped(self):
        self.assertNotEqual(rollup_hash({"a|1": "x" * 64, "b|2": "y" * 64}), rollup_hash({"a|1": "x" * 64}))


if __name__ == "__main__":
    unittest.main()
