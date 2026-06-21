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

### 2026-06-20T21:30:00Z · win-zh · claude
- Changed: Merged main into zh-CN (licensing) and translated
  windows/src/activation.html to Simplified Chinese. Logic identical; same
  embedded public key.
- Affects: nothing new — license cascade complete (mac → win-en → win-zh).
- Others must adapt: nothing. PARITY License row win-zh → ✅.

### 2026-06-21T00:30:00Z · all · claude
- Changed: Bumped Windows version → 0.2.0 (first licensed release). Rewrote
  coordination/fetch-builds.sh to pull the latest licensed installers from CI
  (EN=main, ZH=zh-CN); added scripts/rebuild-all.sh (mac+keygen+windows → builds/).
- Affects: release/versioning + local build tooling.
- Others must adapt: tag v0.2.0 (main) and v0.2.0-zh (zh-CN) to publish releases.
