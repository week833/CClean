"""Stream setup for tools that emit non-ASCII text.

This package writes UTF-8 JSON to stdout and Chinese diagnostics to stderr. On
Windows the console encoding defaults to the active code page (cp1252 on the
GitHub runners), and printing either one raises UnicodeEncodeError before the
caller ever sees the result.

Relying on the environment to set PYTHONUTF8 or PYTHONIOENCODING is not enough:
the程式 may be launched by a scheduler, a service, or another program that does
not inherit those settings. A tool that promises UTF-8 output has to guarantee
its own streams, so every entry point calls use_utf8_streams() first.
"""

from __future__ import annotations

import sys


def use_utf8_streams() -> None:
    """Force stdout and stderr to UTF-8 where the stream allows it.

    Safe to call more than once, and a no-op for streams that cannot be
    reconfigured (a captured StringIO in a test, or a closed stream).
    """
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(encoding="utf-8")
        except (ValueError, OSError):
            # Already detached, or a stream that does not support re-encoding.
            continue
