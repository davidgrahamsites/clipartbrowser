# References

## Apple Frameworks
- SwiftUI for native macOS UI.
- AppKit for image decoding, rendering, and file panels.
- PDFKit for extracting text from PDFs.
- UniformTypeIdentifiers for document import filters.

## External Runtime Services
- Openverse image API: no-key image search with license metadata.
- Wikimedia Commons API: no-key fallback source for image search.

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

