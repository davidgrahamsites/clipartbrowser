# Memory

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

