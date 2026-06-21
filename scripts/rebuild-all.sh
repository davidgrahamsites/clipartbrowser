#!/usr/bin/env bash
# Rebuild EVERY edition into ./builds (kept local, gitignored):
#   - gated macOS app   (built here)
#   - keygen macOS app  (built here)
#   - Windows EN + ZH installers (pulled from the latest successful CI builds)
#
# Usage: scripts/rebuild-all.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p builds

echo "== macOS app (gated) =="
./scripts/package-app.sh release >/dev/null
rm -rf builds/ClipartBrowser.app
cp -R DIST/ClipartBrowser.app builds/ClipartBrowser.app

echo "== keygen app =="
./scripts/package-keygen.sh release >/dev/null

echo "== Windows installers (from CI) =="
./coordination/fetch-builds.sh

echo
echo "All builds in $ROOT/builds:"
ls -lh builds
