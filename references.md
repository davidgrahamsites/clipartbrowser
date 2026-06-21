# References

## Apple Frameworks
- SwiftUI for native macOS UI.
- AppKit for image decoding, rendering, and file panels.
- PDFKit for extracting text from PDFs.
- UniformTypeIdentifiers for document import filters.

## External Runtime Services
- **Current:** embedded web view searching **Google / Baidu / Bing / Yandex**
  (`tbm=isch` / `image.baidu.com` / `bing.com/images` / `yandex.com/images`).
  Full-size image extracted per engine (Google `imgurl`, Baidu `data-objurl`,
  Bing `a.iusc m`-JSON, Yandex `.serp-item data-bem`); app downloads full +
  thumbnail and keeps the bigger one. OCR via Vision (Mac) / Tesseract.js (Win).
- _Historical (not used):_ Openverse / Wikimedia Commons no-key APIs.

## Current Project References (2026-06-21)
- Repo: https://github.com/davidgrahamsites/clipartbrowser
- Releases: `v0.2.0` (EN `.exe`), `v0.2.0-zh` (ZH `.exe`); older `v0.1.0*` are pre-license.
- Editions: macOS (`Sources/`, `main`) · Windows EN (`windows/`, `main`) · Windows ZH (`zh-CN`).
- Coordination: `coordination/{README,HANDOFF,PARITY,SCHEMA,STATUS}.md`.
- Licensing: `licensing/` (keygen + `private.pem` gitignored), `Sources/ClipartKeygen`,
  verify in `LicenseVerifier.swift` / `windows/src/license.js`. Public key:
  `T9N5BJyrn6bEWPxSixZ3v8bscvg+g6dSAjm2dkoPOBs=`.
- CI: `.github/workflows/windows-build.yml` (build + release on tag),
  `parity-check.yml`. Build scripts: `scripts/{package-app,package-keygen,rebuild-all}.sh`,
  `coordination/fetch-builds.sh`. Local builds in `builds/`.
- See `restart.md` for the authoritative current-state guide.

## File Formats
- `.docx` is an Office Open XML ZIP package. Vocabulary text can be extracted from `word/document.xml`.
- `.pptx` is an Office Open XML ZIP package. The exporter should create presentation XML, slide XML, relationships, content types, and media entries.

## Slide Dimensions
PowerPoint uses EMUs.

Letter portrait:
- Width: `8.5 * 914400 = 7772400`
- Height: `11 * 914400 = 10058400`

Pixel padding conversion:
- Treat 96 px as 1 inch.
- `paddingEMU = paddingPixels * 914400 / 96`

