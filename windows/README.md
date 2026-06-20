# ClipartBrowser — Windows (Electron) edition

A Windows 10+ build of ClipartBrowser. The macOS SwiftUI app lives at the repo
root; this is a separate Electron implementation that reuses the same concepts
(embedded multi-engine image search, full-size "bigger of two" picking, and —
as they are ported — image trimming/upscaling and PPTX/word-list export).

## Status

Scaffold + first vertical slice:

- ✅ Embedded image browser with **Google / Baidu / Bing / Yandex** engine picker
- ✅ Universal picker (full-size image extraction per engine, ported from the Mac app)
- ✅ "Bigger of the two" download (full vs thumbnail) with desktop UA + referer
- ⏳ To port: white-trim, Lanczos upscaler (via `sharp`), fit-to-slide, PPTX/DOCX/TXT
  export, document import + OCR (Tesseract.js), vocabulary extraction

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
