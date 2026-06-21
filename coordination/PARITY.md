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
| Vocabulary extraction | ✅ | ✅ | ✅ | shared rules → SCHEMA.md |
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
| Upscaler Preview (compare methods) | ✅ | ✅ | ✅ | mac: window · EN/ZH: modal |
| Export PPTX | ✅ | ✅ | ✅ | OOXML structure → SCHEMA.md |
| Export List (.txt / .docx) | ✅ | ✅ | ✅ | |
| Drag-and-drop import | ✅ | ✅ | ✅ | |
| UI language | en | en | **zh-Hans** | ZH = EN + translation |

## How to use
1. When you change the Mac app, edit the affected rows: set `win-en` (and
   `win-zh`) to 🔧 and add a note describing what changed.
2. Append a HANDOFF.md entry describing the change + impact.
3. The Windows-EN agent ports 🔧 rows, then sets `win-en` ✅.
4. The Windows-ZH agent merges main into zh-CN, translates new strings, sets
   `win-zh` ✅.
