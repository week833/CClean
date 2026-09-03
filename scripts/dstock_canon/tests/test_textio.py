"""Entry points must survive a console that cannot encode their own messages.

These reproduce a real CI failure: on Windows the console defaults to cp1252,
and the Chinese diagnostics this package emits raised UnicodeEncodeError before
the caller saw any result.
"""

from __future__ import annotations

import io
import os
import subprocess
import sys
import unittest
from pathlib import Path

from dstock_canon.textio import use_utf8_streams

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = REPO_ROOT / "scripts"
PARITY = SCRIPTS / "dstock_canon" / "tests" / "check_schema_parity.py"


def _run(args, **extra_env):
    env = dict(os.environ, PYTHONPATH=str(SCRIPTS), PYTHONIOENCODING="cp1252")
    env.pop("PYTHONUTF8", None)
    env.update(extra_env)
    return subprocess.run(
        [sys.executable, *args], cwd=REPO_ROOT, env=env,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )


class LegacyConsoleTests(unittest.TestCase):
    def test_parity_check_survives_a_cp1252_console(self):
        result = _run([str(PARITY)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("UnicodeEncodeError", result.stderr)
        self.assertIn("[OK]", result.stdout)

    def test_cli_error_message_stays_readable_on_a_cp1252_console(self):
        """stderr defaults to backslashreplace, so an unguarded stream degrades
        the operator's message to \\uXXXX escapes instead of crashing."""
        result = _run(["-m", "dstock_canon", "validate-rows", "no_such_file.jsonl"])
        self.assertEqual(result.returncode, 2)
        self.assertNotIn("UnicodeEncodeError", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertIn("[ERROR] 無法讀寫檔案", result.stderr)
        self.assertNotIn("\\u", result.stderr)

    def test_missing_file_is_reported_not_raised(self):
        result = _run(["-m", "dstock_canon", "validate-receipt", "no_such_receipt.json"])
        self.assertEqual(result.returncode, 2)
        self.assertNotIn("Traceback", result.stderr)


class StreamGuardTests(unittest.TestCase):
    def test_calling_twice_is_safe(self):
        use_utf8_streams()
        use_utf8_streams()

    def test_streams_without_reconfigure_are_left_alone(self):
        original_out, original_err = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = io.StringIO(), io.StringIO()
        try:
            use_utf8_streams()
            sys.stdout.write("中文")
            self.assertEqual(sys.stdout.getvalue(), "中文")
        finally:
            sys.stdout, sys.stderr = original_out, original_err


if __name__ == "__main__":
    unittest.main()
