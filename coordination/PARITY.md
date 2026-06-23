# Feature Parity Matrix

**macOS is the source of truth.** Features originate on Mac and flow downstream:
**Mac → Windows EN → Windows ZH**. The `mac` column is the reference; when a Mac
feature is added or changed, set the Windows cells to 🔧 (needs-port). Windows-ZH
stays 🔧 until Windows-EN lands and the new strings are translated.

Legend: ✅ done · 🔧 needs-port · — n/a

| Feature | mac (canon) | win-en | win-zh | Notes |
|---|:--:|:--:|:--:|---|
| Import .docx | ✅ | ✅ | ✅ | EN/ZH: JSZip parse of word/document.xml |
| Import .pdf | ✅ | ✅ | ✅ | EN/ZH: pdfjs-dist (best-effort) |
| Import .rtf / .txt | ✅ | ✅ | ✅ | |
| Image OCR (lesson plan) | ✅ | ✅ | ✅ | mac: Vision · EN/ZH: tesseract.js (CDN model) |
| Vocabulary extraction | ✅ | ✅ | 🔧 | +headings "spelling list/words" (2026-06-20). 2026-06-22: also recognize title-like headings ("Unit 5 Vocabulary", "Week 3 Spelling Words"). mac+win-en done; win-zh merge main into vocabulary.js. |
| Word review + custom terms | ✅ | ✅ | ✅ | |
| Image search: Google/Baidu/Bing/Yandex | ✅ | ✅ | ✅ | engine list → SCHEMA.md |
| Universal picker (full-size extraction) | ✅ | ✅ | ✅ | extraction keys → SCHEMA.md |
| Bigger-of-two download | ✅ | ✅ | ✅ | |
| White-trim | ✅ | ✅ | ✅ | tolerance 245 / alpha ≤ 8 |
| Fit-to-slide pixel sizing | ✅ | ✅ | ✅ | EMU constants → SCHEMA.md |
| Upscaler (Lanczos) + method dropdown | ✅ | ✅ | ✅ | mac: Core Image/vImage · EN/ZH: pica/canvas |
| Flashcard grid (padding/orientation/labels) | ✅ | ✅ | ✅ | |
| Card selection / retry / remove | ✅ | ✅ | ✅ | |
| Browser zoom controls | ✅ | ✅ | ✅ | |
| Browser bar: engine selector on its own row | 🔧 | ✅ | 🔧 | 2026-06-23: win-en split `#browser-bar` into a tab row + a tool row (labeled "Search engine:" select) so a long tab list no longer hides the engine picker. Windows-originated UX fix; reconcile with Mac (canon). win-zh: merge + translate label. |
| Inspect-image mode (full-size preview before add) | 🔧 | ✅ | 🔧 | 2026-06-23: win-en added a toggle "🔍 Inspect"; when on, clicking a result downloads it and shows a full-size modal (check watermarks) with Use / Skip, instead of adding immediately. Windows-originated; reconcile with Mac (canon). win-zh: merge + translate toggle/modal strings. |
| Upscaler Preview (compare methods) | ✅ | ✅ | ✅ | mac: window · EN/ZH: modal |
| Export PPTX | ✅ | ✅ | ✅ | OOXML structure → SCHEMA.md |
| Export List (.txt / .docx) | ✅ | ✅ | ✅ | |
| Drag-and-drop import | ✅ | ✅ | ✅ | |
| License activation (one-per-computer) | ✅ | ✅ | 🔧 | Ed25519 machine-locked; activation.html translated. Keygen = Mac-only ClipartKeygen.app. 2026-06-22: EN added top-level `productName` so each edition uses its own userData/license store (was shared, so ZH never prompted). win-zh: add top-level `productName: "ClipartBrowser CN"`, bump 0.2.2-zh. |
| UI language | en | en | **zh-Hans** | ZH = **interface-only** translation (UI + engine names + 剪贴画 qualifier); document vocabulary is NOT translated |

## How to use
1. When you change the Mac app, edit the affected rows: set `win-en` (and
   `win-zh`) to 🔧 and add a note describing what changed.
2. Append a HANDOFF.md entry describing the change + impact.
3. The Windows-EN agent ports 🔧 rows, then sets `win-en` ✅.
4. The Windows-ZH agent merges main into zh-CN, translates new strings, sets
   `win-zh` ✅.
