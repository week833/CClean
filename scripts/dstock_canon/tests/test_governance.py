"""Authorisation is separate from measurement, and defaults to refusing."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from unittest import mock

from dstock_canon.governance import (
    DEFAULT,
    ENV_VAR,
    Governance,
    GovernanceError,
    default_governance,
    from_mapping,
    load,
)

RATIFIED_DOC = {
    "schema": "dstock.market.source_governance",
    "schema_version": 1,
    "ratified_classes": ["primary", "backup"],
    "adr": "ADR-0002",
    "ratified_at": "2026-09-10",
}


class DefaultTests(unittest.TestCase):
    def test_the_default_is_the_pre_adr_state(self):
        self.assertTrue(DEFAULT.allows("primary"))
        self.assertFalse(DEFAULT.allows("backup"))
        self.assertFalse(DEFAULT.allows("reference_only"))

    def test_default_governance_returns_it(self):
        self.assertIs(default_governance(), DEFAULT)


class DeclarationTests(unittest.TestCase):
    def test_a_valid_declaration_ratifies_backup(self):
        governance = from_mapping(RATIFIED_DOC)
        self.assertTrue(governance.allows("backup"))
        self.assertEqual(governance.describe()["adr"], "ADR-0002")

    def test_reference_only_can_never_be_ratified(self):
        doc = dict(RATIFIED_DOC, ratified_classes=["primary", "reference_only"])
        with self.assertRaises(GovernanceError):
            from_mapping(doc)

    def test_primary_must_be_listed(self):
        doc = dict(RATIFIED_DOC, ratified_classes=["backup"])
        with self.assertRaises(GovernanceError):
            from_mapping(doc)

    def test_ratifying_backup_requires_an_audit_date(self):
        doc = {name: value for name, value in RATIFIED_DOC.items() if name != "ratified_at"}
        with self.assertRaises(GovernanceError):
            from_mapping(doc)

    def test_ratifying_only_primary_needs_no_date(self):
        doc = {name: value for name, value in RATIFIED_DOC.items() if name != "ratified_at"}
        doc["ratified_classes"] = ["primary"]
        self.assertFalse(from_mapping(doc).allows("backup"))

    def test_an_adr_must_be_named(self):
        with self.assertRaises(GovernanceError):
            from_mapping(dict(RATIFIED_DOC, adr="  "))

    def test_unknown_fields_and_classes_are_rejected(self):
        with self.assertRaises(GovernanceError):
            from_mapping(dict(RATIFIED_DOC, sneaky=1))
        with self.assertRaises(GovernanceError):
            from_mapping(dict(RATIFIED_DOC, ratified_classes=["primary", "superuser"]))

    def test_wrong_schema_or_version_is_rejected(self):
        with self.assertRaises(GovernanceError):
            from_mapping(dict(RATIFIED_DOC, schema="something.else"))
        with self.assertRaises(GovernanceError):
            from_mapping(dict(RATIFIED_DOC, schema_version=2))


class LoadTests(unittest.TestCase):
    def setUp(self):
        self._folder = tempfile.TemporaryDirectory()
        self.addCleanup(self._folder.cleanup)
        self.path = os.path.join(self._folder.name, "governance.json")

    def _write(self, doc):
        with open(self.path, "w", encoding="utf-8") as handle:
            json.dump(doc, handle)

    def test_no_declaration_falls_back_to_the_safe_default(self):
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop(ENV_VAR, None)
            self.assertIs(load(), DEFAULT)

    def test_a_missing_file_is_the_pre_adr_state_not_an_error(self):
        self.assertIs(load(self.path), DEFAULT)

    def test_a_declared_file_is_honoured(self):
        self._write(RATIFIED_DOC)
        self.assertTrue(load(self.path).allows("backup"))

    def test_the_env_var_is_read_when_no_path_is_given(self):
        self._write(RATIFIED_DOC)
        with mock.patch.dict(os.environ, {ENV_VAR: self.path}):
            self.assertTrue(load().allows("backup"))

    def test_a_malformed_declaration_raises_rather_than_silently_widening(self):
        with open(self.path, "w", encoding="utf-8") as handle:
            handle.write("{not json")
        with self.assertRaises(GovernanceError):
            load(self.path)

    def test_an_unsafe_declaration_raises(self):
        self._write(dict(RATIFIED_DOC, ratified_classes=["primary", "reference_only"]))
        with self.assertRaises(GovernanceError):
            load(self.path)


class ImmutabilityTests(unittest.TestCase):
    def test_a_governance_value_cannot_be_edited_in_place(self):
        governance = from_mapping(RATIFIED_DOC)
        with self.assertRaises(Exception):
            governance.ratified_classes = frozenset({"primary", "backup", "reference_only"})

    def test_describe_does_not_leak_a_mutable_set(self):
        governance = from_mapping(RATIFIED_DOC)
        described = governance.describe()
        described["ratified_classes"].append("reference_only")
        self.assertFalse(Governance(
            ratified_classes=governance.ratified_classes, adr=governance.adr,
        ).allows("reference_only"))


if __name__ == "__main__":
    unittest.main()
