#!/usr/bin/env bash
# Continuous conflict watcher (the "nervous system").
# Watches coordination/HANDOFF.md; on each change, asks a headless Claude to scan
# recent entries for conflicts and writes CLEAR/CONFLICT to STATUS.md.
#
# Requirements: fswatch (brew install fswatch), claude CLI on PATH.
# Run from anywhere:  coordination/watch.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COORD="$ROOT/coordination"
HANDOFF="$COORD/HANDOFF.md"
STATUS="$COORD/STATUS.md"

command -v fswatch >/dev/null || { echo "Install fswatch: brew install fswatch"; exit 1; }
command -v claude  >/dev/null || { echo "claude CLI not found on PATH"; exit 1; }

echo "Watching $HANDOFF for conflicts (Ctrl-C to stop)…"

check() {
  local ts out
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  out="$(claude -p "Read $HANDOFF and $COORD/SCHEMA.md. Look only at the last 5 HANDOFF entries. If any two recent changes conflict or break the SCHEMA contract across editions, output exactly: CONFLICT: <one-line reason>. Otherwise output exactly: CLEAR" 2>/dev/null | tr -d '\r' | tail -1)"
  if printf '%s' "$out" | grep -qi '^CONFLICT'; then
    printf '\n%s · %s\n' "$out" "$ts" >> "$STATUS"
    command -v osascript >/dev/null && \
      osascript -e "display notification \"$out\" with title \"ClipartBrowser conflict\"" || true
    echo "[$ts] $out"
  else
    printf '\nCLEAR · %s · watcher\n' "$ts" >> "$STATUS"
    echo "[$ts] CLEAR"
  fi
}

# Debounce: coalesce rapid edits within 2s.
fswatch -o "$HANDOFF" | while read -r _; do
  sleep 2
  check
done
