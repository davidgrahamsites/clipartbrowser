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
