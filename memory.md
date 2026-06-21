# Memory

> **UPDATE 2026-06-21 (see `restart.md`).** Superseded/added since the list below:
> - Image search is an **embedded web view** over Google/Baidu/Bing/Yandex (NOT
>   Openverse/Wikimedia). Picker extracts the full-size image per engine; the app
>   downloads full + thumbnail and keeps the **bigger** one.
> - **Three editions**, one repo, one-way cascade Mac → Win-EN (`windows/`,
>   Electron) → Win-ZH (`zh-CN`). Coordination in `coordination/`.
> - **Licensing**: Ed25519 one-per-computer activation, hard-block on launch, all
>   editions. Keys issued by Mac-only `ClipartKeygen.app`; private key
>   `licensing/private.pem` (gitignored); embedded public key
>   `T9N5BJyrn6bEWPxSixZ3v8bscvg+g6dSAjm2dkoPOBs=`.
> - Windows installers built by CI; releases on `vX.Y.Z` / `vX.Y.Z-zh` tags; local
>   builds in `builds/` (gitignored).

## Durable Decisions
- Native SwiftUI macOS app.
- Swift Package layout instead of a hand-authored Xcode project.
- Package the built executable into a `.app` bundle after `swift build`.
- Keep document import, image search, trimming, preview, and PPTX export in app code.
- Use Openverse as the default image provider because it returns direct image URLs and license metadata without a key.
- Add Wikimedia Commons as a fallback image provider where useful.
- Use ZIPFoundation to handle ZIP-based formats:
  - Read `.docx` by extracting `word/document.xml`.
  - Write `.pptx` as a standard Office Open XML zip package.
- Use PDFKit for PDF text extraction.
- Use AppKit image APIs for trimming and PNG export.

## Known Requirements To Preserve
- Vocabulary detection must not turn every word in a document into a card.
- The app should review detected words before fetching images.
- The app should review finished flashcards before creating the PPT.
- Default card padding is 12 px and must be adjustable.
- Flashcard slides should be letter portrait size: 8.5 x 11 inches.

