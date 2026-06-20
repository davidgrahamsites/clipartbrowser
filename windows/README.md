# ClipartBrowser — Windows (Electron) edition

A Windows 10+ build of ClipartBrowser. The macOS SwiftUI app lives at the repo
root; this is a separate Electron implementation that reuses the same concepts
(embedded multi-engine image search, full-size "bigger of two" picking, and —
as they are ported — image trimming/upscaling and PPTX/word-list export).

## Status

Full feature parity with the macOS app:

- ✅ Document import: **.docx / .txt / .rtf / .pdf** + **image OCR** (Tesseract.js)
- ✅ Vocabulary extraction (ported from the Swift `VocabularyExtractor`)
- ✅ Word review (checkboxes + add custom terms)
- ✅ Embedded image browser with **Google / Baidu / Bing / Yandex** engine picker
- ✅ Universal picker + "bigger of the two" download (full vs thumbnail)
- ✅ Image processing: white-trim, fit-to-slide pixel sizing, upscaler
  (Lanczos via `pica`; method dropdown)
- ✅ Flashcard grid with padding / orientation / labels / selection / retry / remove
- ✅ **Export PPTX** (OOXML via JSZip) and **Export List** (.txt / .docx)
- ✅ Drag-and-drop import

Image search/processing/export run with no native modules (pure JS/WASM), so the
build needs no platform compilation. OCR downloads its language data from a CDN on
first use (needs internet, which the app uses for image search anyway).

## Develop

```powershell
cd windows
npm install
npm start
```

## Build the installer (.exe)

Locally on Windows:

```powershell
cd windows
npm install
npm run dist      # produces dist/ClipartBrowser Setup <version>.exe (NSIS)
```

Or let CI do it: the **Build Windows app** GitHub Actions workflow runs on a
`windows-latest` runner for any push touching `windows/**` and uploads the `.exe`
as a build artifact (and attaches it to GitHub Releases on tags).

## Notes

- Unsigned builds trigger a Windows SmartScreen warning ("More info → Run anyway").
  Code signing requires a certificate and can be added to the workflow later.
- Baidu pages may trigger a "local network" prompt and Yandex may show a captcha
  after many rapid searches — same engine-side behaviors as the macOS app.
