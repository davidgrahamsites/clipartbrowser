#!/usr/bin/env bash
# Download every published installer into ./builds (kept local, gitignored).
# Usage: coordination/fetch-builds.sh
set -euo pipefail

REPO="davidgrahamsites/clipartbrowser"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/builds"
mkdir -p "$DEST"

echo "Fetching release installers from $REPO into $DEST ..."
for tag in $(gh release list -R "$REPO" --json tagName -q '.[].tagName'); do
  echo "  • $tag"
  gh release download "$tag" -R "$REPO" -D "$DEST" --clobber --pattern '*.exe' 2>/dev/null || true
done

echo "Done. Local builds:"
ls -lh "$DEST"
