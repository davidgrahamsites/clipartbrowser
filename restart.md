# Restart Guide — Current State

> This file reflects the project **as it actually is now**. Older sections of
> context.md / memory.md / references.md describe the original (pre-git,
> Openverse-provider) design and are historical only.

## What this is
ClipartBrowser turns a vocabulary document into clipart flashcards and a `.pptx`.
It ships as **three editions in one repo** (github.com/davidgrahamsites/clipartbrowser):

| Edition | Tech | Location | Releases |
|---|---|---|---|
| **macOS** (source of truth) | Swift / SwiftUI | repo root (`Sources/`, `main`) | built locally → `.app` |
| **Windows EN** | Electron | `windows/` (`main`) | tag `vX.Y.Z` |
| **Windows ZH** (简体中文) | Electron | `zh-CN` branch | tag `vX.Y.Z-zh` |

Features flow **one way: Mac → Win-EN → Win-ZH** (ZH = EN + translated UI; it does
**not** translate document content). Coordination lives in `coordination/` — read
`coordination/README.md`.

Current version: **0.2.0** (first licensed release). Releases: `v0.2.0`, `v0.2.0-zh`.

## How image search actually works (superseded the old Openverse plan)
Images come from an **embedded web view** (WKWebView on Mac, `<webview>` on
Windows) searching **Google / Baidu / Bing / Yandex** (user-selectable). A picker
script extracts the full-size image per engine; the app downloads **both** the
full image and the thumbnail and keeps the **bigger** one, then trims white,
fits-to-slide, and upscales (Lanczos). Contract: `coordination/SCHEMA.md`.

## Licensing (one-per-computer)
Ed25519 machine-locked activation, hard-block on launch, in all three editions.
- Verify code: `Sources/ClipartBrowserCore/LicenseVerifier.swift`,
  `Sources/ClipartBrowser/LicenseManager.swift`, `windows/src/license.js`.
- **Issue keys** with the Mac-only **ClipartKeygen.app** (`Sources/ClipartKeygen`,
  build via `scripts/package-keygen.sh`). It signs a customer's Machine ID.
- Private key: `licensing/private.pem` (**gitignored, never ship, back it up**).
  Embedded public key (all editions): `T9N5BJyrn6bEWPxSixZ3v8bscvg+g6dSAjm2dkoPOBs=`
- Full workflow: `licensing/README.md`.

## Commands
```sh
swift test                       # Core + license tests
swift build                      # all targets (app, keygen, core)
./scripts/package-app.sh release # build macOS .app → DIST/
./scripts/package-keygen.sh release   # build keygen → builds/ClipartKeygen.app
./scripts/rebuild-all.sh         # mac app + keygen + Windows installers → builds/
./coordination/fetch-builds.sh   # refresh Windows installers in builds/ from CI
cd windows && npm install && npm start   # run Windows app locally
cd windows && node test-logic.js         # Windows pure-logic tests
```

## Builds / releases
- All local builds live in **`builds/`** (gitignored): both `.exe` installers +
  `ClipartBrowser.app` + `ClipartKeygen.app`.
- Windows `.exe`s are built by **CI** (`.github/workflows/windows-build.yml`,
  `windows-latest`) — you can't compile them on a Mac. Pushing a `vX.Y.Z` tag
  publishes a GitHub Release with the installer.
- `.github/workflows/parity-check.yml` opens an issue if `Sources/**` changes on
  `main` without `windows/**` (a parity reminder).
- Installers are **unsigned** (SmartScreen/Gatekeeper warn). Windows signing is
  wired in the workflow but needs a cert (secrets `WINDOWS_CERT_BASE64` /
  `WINDOWS_CERT_PASSWORD`).

## Cutting a new release
1. Change Mac → port to `windows/` (Win-EN) → merge `main` into `zh-CN` + translate.
2. Bump `windows/package.json` `version`.
3. `git tag -a vX.Y.Z -m "…" && git push origin vX.Y.Z` (EN).
4. `git checkout zh-CN && git merge main && git push` then
   `git tag -a vX.Y.Z-zh && git push origin vX.Y.Z-zh` (ZH).
5. `./coordination/fetch-builds.sh` to pull the installers local.
