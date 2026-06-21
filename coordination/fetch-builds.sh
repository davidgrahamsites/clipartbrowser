#!/usr/bin/env bash
# Refresh the local Windows installers in ./builds from the latest *successful*
# CI builds: EN from `main`, ZH from `zh-CN`. (Mac apps are built locally with
# scripts/package-app.sh + scripts/package-keygen.sh.)
#
# Usage: coordination/fetch-builds.sh
set -euo pipefail

REPO="davidgrahamsites/clipartbrowser"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/builds"
mkdir -p "$DEST"

command -v gh >/dev/null || { echo "GitHub CLI (gh) not found on PATH."; exit 1; }

fetch_branch() {
  local branch="$1" label="$2" id
  id="$(gh run list -R "$REPO" --workflow windows-build.yml --branch "$branch" \
        --status success -L 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  if [ -z "$id" ]; then
    echo "  ! no successful Windows build on '$branch' yet"
    return
  fi
  echo "  • $label  (run $id @ $branch)"
  gh run download "$id" -R "$REPO" -n ClipartBrowser-Windows -D "$DEST" \
    || echo "    download failed (artifact may have expired)"
}

echo "Refreshing Windows installers into $DEST ..."
rm -f "$DEST"/*.exe
fetch_branch main "Windows EN"
fetch_branch zh-CN "Windows ZH"

echo "Local installers:"
ls -lh "$DEST"/*.exe 2>/dev/null || echo "  (none)"
