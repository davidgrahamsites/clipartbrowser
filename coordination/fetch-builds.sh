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

# Download to a temp dir and only move into builds/ on success, with retries —
# so a network timeout NEVER deletes an existing local installer.
fetch_branch() {
  local branch="$1" label="$2" id tmp attempt
  id="$(gh run list -R "$REPO" --workflow windows-build.yml --branch "$branch" \
        --status success -L 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  if [ -z "$id" ]; then
    echo "  ! no successful Windows build on '$branch' yet (kept any existing local copy)"
    return
  fi
  echo "  • $label  (run $id @ $branch)"
  for attempt in 1 2 3; do
    tmp="$(mktemp -d)"
    if gh run download "$id" -R "$REPO" -n ClipartBrowser-Windows -D "$tmp" 2>/dev/null; then
      mv -f "$tmp"/*.exe "$DEST"/ 2>/dev/null && echo "    updated" || echo "    (no .exe in artifact)"
      rm -rf "$tmp"
      return
    fi
    rm -rf "$tmp"
    echo "    attempt $attempt failed, retrying…"
  done
  echo "    download failed after 3 tries — kept existing local copy"
}

echo "Refreshing Windows installers into $DEST (existing copies preserved on failure) ..."
fetch_branch main "Windows EN"
fetch_branch zh-CN "Windows ZH"

echo "Local installers:"
ls -lh "$DEST"/*.exe 2>/dev/null || echo "  (none)"
