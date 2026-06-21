#!/usr/bin/env python3
"""Continuous conflict watcher (Python / watchdog variant).

Watches coordination/HANDOFF.md; on change, asks a headless Claude to scan the
recent entries for conflicts and appends CLEAR/CONFLICT to STATUS.md.

Setup:  pip install watchdog   (add --break-system-packages if needed)
Run:    python coordination/monitor.py
"""
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

ROOT = Path(__file__).resolve().parent.parent
COORD = ROOT / "coordination"
HANDOFF = COORD / "HANDOFF.md"
SCHEMA = COORD / "SCHEMA.md"
STATUS = COORD / "STATUS.md"

PROMPT = (
    f"Read {HANDOFF} and {SCHEMA}. Look only at the last 5 HANDOFF entries. "
    "If any two recent changes conflict or break the SCHEMA contract across "
    "editions, output exactly: CONFLICT: <one-line reason>. Otherwise output "
    "exactly: CLEAR"
)


def now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def check() -> None:
    try:
        result = subprocess.run(
            ["claude", "-p", PROMPT],
            capture_output=True, text=True, timeout=120,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"[{now()}] watcher error: {exc}")
        return
    out = (result.stdout or "").strip().splitlines()
    verdict = out[-1].strip() if out else "CLEAR"
    if verdict.upper().startswith("CONFLICT"):
        line = f"\n{verdict} · {now()}\n"
    else:
        line = f"\nCLEAR · {now()} · watcher\n"
    STATUS.open("a", encoding="utf-8").write(line)
    print(f"[{now()}] {verdict}")


class Handler(FileSystemEventHandler):
    def __init__(self) -> None:
        self._last = 0.0

    def on_modified(self, event) -> None:
        if Path(event.src_path).name != "HANDOFF.md":
            return
        now_t = time.time()
        if now_t - self._last < 2:  # debounce
            return
        self._last = now_t
        check()


def main() -> None:
    obs = Observer()
    obs.schedule(Handler(), str(COORD), recursive=False)
    obs.start()
    print(f"Watching {HANDOFF} (Ctrl-C to stop)…")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        obs.stop()
    obs.join()


if __name__ == "__main__":
    main()
