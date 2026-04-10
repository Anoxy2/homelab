#!/usr/bin/env python3
"""Shared Python helpers for skill-forge shell scripts.

This module centralizes common JSON operations used from inline Python blocks.
"""

from __future__ import annotations

import fcntl
import json
import os
import tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterator


def utc_now_iso() -> str:
    """Return current UTC timestamp in ISO-8601 Z format."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_json_file(path: str | Path, default: Any = None) -> Any:
    """Read JSON from path and return default on decode/missing errors.

    If the file is corrupt (JSONDecodeError), attempts auto-restore from
    the .bak file written by write_json_atomic before returning default.
    """
    p = Path(path)
    if not p.exists():
        return default
    try:
        with p.open("r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        bak = p.with_suffix(".bak")
        if bak.exists():
            try:
                with bak.open("r", encoding="utf-8") as f:
                    data = json.load(f)
                import shutil
                shutil.copy2(str(bak), str(p))
                return data
            except (json.JSONDecodeError, OSError):
                pass
        return default
    except OSError:
        return default


def write_json_atomic(path: str | Path, payload: Any) -> None:
    """Atomically write JSON payload to file using fsync + rename.

    Before replacing, the existing file is copied to <name>.bak so that
    a corrupt write can be recovered manually or by read_json_file fallback.
    """
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    bak = p.with_suffix(".bak")
    fd, tmp_path = tempfile.mkstemp(prefix=".tmp-", suffix=".json", dir=str(p.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, sort_keys=True)
            f.flush()
            os.fsync(f.fileno())
        if p.exists():
            import shutil
            shutil.copy2(str(p), str(bak))
        os.replace(tmp_path, p)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


@contextmanager
def file_lock(lock_path: str | Path) -> Iterator[None]:
    """Exclusive advisory file lock (blocking)."""
    p = Path(lock_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def locked_json_update(path: str | Path, lock_path: str | Path, updater: Callable[[Any], Any], default: Any) -> Any:
    """Update JSON payload under a lock and persist atomically."""
    with file_lock(lock_path):
        data = read_json_file(path, default)
        new_payload = updater(data)
        write_json_atomic(path, new_payload)
        return new_payload
