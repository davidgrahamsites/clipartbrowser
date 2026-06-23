# HANDOFF Log

Append-only coordination log. **Append, never overwrite** (avoids races). Newest
entries at the bottom. One entry per completed change.

Entry template:
```
### <ISO-8601 timestamp> · <edition: mac | win-en | win-zh> · <author>
- Changed: <what you did>
- Affects: <API surface / data shape / pipeline / file format / shared contract>
- Others must adapt: <what downstream editions need to do, or "nothing">
```

---

### 2026-06-20 · all · setup
- Changed: Established the cross-edition coordination layer (HANDOFF, PARITY,
  SCHEMA, STATUS) and the one-way protocol Mac → Win-EN → Win-ZH.
- Affects: process only.
- Others must adapt: read this file + STATUS.md before each task; log here after.

### 2026-06-20T19:08:00Z · mac · claude
- Changed: VocabularyExtractor now recognizes the headings "spelling list" and
  "spelling words" (Sources/ClipartBrowserCore/VocabularyExtractor.swift).
- Affects: SHARED CONTRACT — the vocabulary heading-words list (SCHEMA.md).
- Others must adapt: win-en + win-zh add the same two headings to
  windows/src/lib/vocabulary.js HEADING_WORDS. PARITY "Vocabulary extraction"
  row flipped to 🔧 for win-en/win-zh.

### 2026-06-20T19:09:00Z · win-en · claude
- Changed: Ported the "spelling list"/"spelling words" headings to
  windows/src/lib/vocabulary.js HEADING_WORDS (matches SCHEMA + Mac).
- Affects: nothing new — keeps the shared vocabulary contract in sync.
- Others must adapt: win-zh picks this up by merging main into zh-CN (no string
  translation needed; headings are matched lowercased). win-en PARITY → ✅.

### 2026-06-20T19:10:00Z · win-zh · claude
- Changed: Merged main into zh-CN — the spelling-headings vocab change flows in
  automatically (extraction logic is shared; ZH translates UI only, not content).
- Affects: nothing — confirms ZH is interface-only (see SCHEMA "Localization").
- Others must adapt: nothing. win-zh PARITY → ✅. Cascade complete: mac → en → zh.

### 2026-06-20T19:20:00Z · all · claude
- Changed: Added an "Engineering Principles" section (Think Before Coding,
  Simplicity First, Surgical Changes, Goal-Driven Execution) to claude.md and
  windows/CLAUDE.md (global ~/CLAUDE.md already had it).
- Affects: process only — applies to every edition's agents.
- Others must adapt: nothing; merged to zh-CN.

### 2026-06-20T21:25:00Z · mac+win-en · claude
- Changed: Added one-per-computer license activation (Ed25519, machine-locked,
  hard-block on launch). New: Core LicenseVerifier (+tests), app LicenseManager +
  ActivationView gate, Mac-only ClipartKeygen.app issuer (Sources/ClipartKeygen,
  scripts/package-keygen.sh). Win-EN: windows/src/license.js + activation.html +
  main.js gate. Shared contract in SCHEMA "License" (embedded public key).
- Affects: SHARED CONTRACT (license format + embedded public key) + app launch
  flow in every edition.
- Others must adapt: win-zh translate windows/src/activation.html (logic
  identical); set PARITY win-zh ✅. Keygen + private key stay Mac-only, never
  shipped.

### 2026-06-21T00:30:00Z · all · claude
- Changed: Bumped Windows version → 0.2.0 (first licensed release). Rewrote
  coordination/fetch-builds.sh to pull the latest licensed installers from CI
  (EN=main, ZH=zh-CN); added scripts/rebuild-all.sh (mac+keygen+windows → builds/).
- Affects: release/versioning + local build tooling.
- Others must adapt: tag v0.2.0 (main) and v0.2.0-zh (zh-CN) to publish releases.

### 2026-06-21T05:30:00Z · all · claude
- Changed: Hardened coordination/fetch-builds.sh (temp-dir + retries; never delete
  on failure — it had wiped the local EN installer on a timeout). Refreshed docs to
  current reality: rewrote restart.md, updated claude.md architecture, bugs.md
  (Windows/CI/licensing fixes), references.md/context.md/memory.md/agents.md.
- Affects: docs + local build tooling only.
- Others must adapt: nothing. restart.md is now the authoritative current-state doc.

### 2026-06-21T06:00:00Z · win-en+win-zh · claude
- Changed: FIX — Windows activation screen was dead (Machine ID stuck on "…",
  Copy/Activate did nothing): the inline <script> in activation.html was blocked
  by CSP. Moved it to external windows/src/activation.js (CSP script-src 'self'),
  used Electron clipboard, localized error via body[data-invalid]. Bumped → 0.2.1.
  Verified by headlessly rendering activation.html (real Machine ID shown).
- Affects: Windows licensing gate only (Mac SwiftUI gate was already fine).
- Others must adapt: win-zh keep the same external-script structure in the
  translated activation.html. Release v0.2.1 / v0.2.1-zh.

### 2026-06-22T00:00:00Z · win-en (+win-zh needs-port) · claude
- Changed: FIX — Windows ZH never prompted for license activation because both
  editions shared one license store. Root cause: Electron's `app.getName()` (which
  drives `userData`) reads the *top-level* package.json `productName`/`name`, not
  `build.productName`. Both editions had identical top-level `name`
  (`clipartbrowser-windows`) and no top-level `productName`, so both used
  `%APPDATA%/clipartbrowser-windows` and shared `license.json`. Added a top-level
  `productName: "ClipartBrowser"` to windows/package.json and bumped → 0.2.2.
- Affects: per-edition runtime identity / userData path / license + localStorage
  isolation (no shared-contract or file-format change; the key format is unchanged).
- Others must adapt: win-zh — add top-level `productName: "ClipartBrowser CN"` to
  windows/package.json (keep build.appId `...zh` and build.productName as-is), bump
  to 0.2.2-zh. This is what makes ZH activate independently and proves the ZH key
  mechanism works. Note for both: existing 0.2.0/0.2.1 installs move to a new
  userData folder and must re-activate once (same machine key works).
- Also triaged (no code change): import "did not populate" was NOT reproducible —
  docx/txt/rtf populate from source and from a packed app.asar; vocabulary port
  matches Mac exactly. ZH installer Defender block = unsigned-installer SmartScreen,
  expected (no signing cert configured). See bugs.md 2026-06-22.

### 2026-06-22T01:00:00Z · mac + win-en (win-zh needs-port) · claude
- Changed: FIX — vocabulary import returned an empty word list for documents
  whose heading is a title like "Unit 5 Vocabulary" / "Week 3 Spelling Words"
  (the matcher required an exact heading phrase). Broadened `isVocabularyHeading`
  to also accept short title-like lines that END WITH a known heading phrase when
  the leading qualifier is light (≤2 words or contains a number). Sentences merely
  ending in "vocabulary" and heading-less docs are still (correctly) ignored.
- Where: macOS source of truth `Sources/ClipartBrowserCore/VocabularyExtractor.swift`
  (+3 tests, `swift test` green); ported identically to
  `windows/src/lib/vocabulary.js` (+`windows/test-logic.js`, green). Verified
  end-to-end through the real Electron importer on a generated "Unit 5 Vocabulary"
  docx.
- Affects: vocabulary-extraction behavior (shared rule). No data/format change.
- Others must adapt: win-zh — merge `main`; `vocabulary.js` is logic-only (not
  translated) so the port is a straight merge, then set PARITY win-zh ✅. Re-run
  `node test-logic.js`.

### 2026-06-23T00:00:00Z · win-en (win-zh needs-port) · claude
- Changed: Two Windows-EN UI fixes (user-reported, Windows-originated — reconcile
  with Mac as canon, do not treat as Mac-derived). (1) The search-engine `<select>`
  was hard to find: `#browser-bar` was a single flex row where `#tabs` (flex:1) ate
  the width and pushed the engine picker to the far right. Split the bar into a
  `#tab-row` (‹ tabs ›) and a `#tool-row` with a labeled "Search engine:" select +
  zoom/reload/close. (2) New "🔍 Inspect" toggle (persisted in localStorage). When
  on, clicking a search result downloads it (via existing `download-bigger`) and
  shows a full-size modal so the teacher can check for watermarks, then Use / Skip;
  when off, behavior is unchanged (adds immediately). Refactored `handlePick` to
  split download from a new `commitPick`.
- Where: `windows/src/index.html` (markup + CSS), `windows/src/renderer.js`
  (state.inspect/pendingInspect, handlePick/commitPick, showInspect/useInspect/
  closeInspect, setInspectMode, wiring). `node --check` + `node test-logic.js` green.
- Affects: Windows-EN renderer UI only. No shared contract, file format, picker
  extraction keys, or pipeline change.
- Others must adapt: win-zh — merge `main`; translate the new strings only
  ("Search engine:", "🔍 Inspect", "Inspect image", "Use this image", "Skip");
  logic is unchanged. Then set the two new PARITY rows win-zh ✅. Mac (canon):
  these are downstream UX improvements to fold back when convenient.

### 2026-06-23T02:00:00Z · all · claude
- Changed: Decision (no code) — the two 2026-06-23 Windows UX changes (engine
  selector on its own row; "🔍 Inspect" full-size pop-up) are **Windows-only**.
  Per the user, the macOS app's native layout/flow is already fine and does NOT
  want the large selector or the inspect pop-up. PARITY `mac` cells for both rows
  flipped 🔧 → — (n/a). Nothing to port to Mac.
- Affects: coordination/PARITY.md only.
- Others must adapt: nothing.
