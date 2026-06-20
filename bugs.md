# Bugs And Fixes

This file records user-reported bugs or workflow problems and the fix applied.

## 2026-06-17

### Flashcard images were not centered
- Symptom: Images in flashcard previews could sit off-center because the artwork shared a top-trailing `ZStack` alignment with the retry button.
- Fix: Centered the artwork layer horizontally and vertically, and moved the retry button into a separate top-trailing overlay.
- Verification: `swift test`, `swift build`.

### Automatically selected images were poor
- Symptom: The app chose unsuitable image-search results without enough user control.
- Fix: Replaced automatic image choice with an in-app WebKit Google Images picker. Each selected vocabulary word opens as a tab, and the user chooses the image.
- Verification: `swift test`, `swift build`, packaged app launch.

### Image picking initially used an external browser-style flow
- Symptom: Opening image searches outside the app would make the workflow awkward and disconnected.
- Fix: Embedded Google Images in the app with `WKWebView` instead of launching a separate browser window.
- Verification: `swift test`, `swift build`, packaged app launch.

### Image picking required an unnecessary second confirmation
- Symptom: After clicking an image in the embedded browser, the app required a separate `Use Selected Image` action.
- Fix: Browser image clicks now immediately import the clicked image as the final choice and advance the workflow. The secondary selected-image state and button were removed.
- Verification: `swift test`, `swift build`, packaged app launch.

### Lesson-plan screenshots could not be imported as source material
- Symptom: A lesson plan stored as an image, such as a JPG screenshot, could not be imported to extract vocabulary words.
- Fix: Added Vision OCR for image documents and allowed image files in the import panel. The extractor supports common macOS-decodable image types such as JPG/JPEG, PNG, HEIC/HEIF, TIFF/TIF, BMP, GIF, and WebP where available.
- Verification: Added PNG and JPEG OCR tests, verified the provided lesson-plan JPG OCR text, `swift test`, `swift build`, packaged app launch.

### Lesson-plan OCR vocabulary sections needed better parsing
- Symptom: OCR text from lesson plans could contain `Key Words` and `Key Sentences` sections, and the extractor needed to stop before sentence examples.
- Fix: Updated vocabulary extraction to handle `Key Words` sections, OCR-smushed `Key Words summer, hot...` lines, and `Key Sentences` stop headings.
- Verification: Added lesson-plan vocabulary tests, `swift test`.

### PPT orientation was fixed to portrait
- Symptom: PPT export was hard-coded to letter portrait.
- Fix: Added a Portrait/Landscape orientation control and passed the selected orientation into the PPTX exporter.
- Verification: Added portrait and landscape exporter tests, `swift test`, `swift build`.

### Flashcard preview did not reflect landscape export
- Symptom: Choosing landscape output would be misleading if the flashcard preview stayed portrait.
- Fix: The flashcard preview aspect ratio now follows the selected PPT orientation.
- Verification: `swift test`, `swift build`, packaged app launch.

### Files could not be dragged onto the app to import
- Symptom: Source documents/images had to be chosen through the Import button.
- Fix: Added app-wide file drag-and-drop support. Dropped files are filtered to supported document/image types and then routed through the same import/OCR flow as the Import button.
- Verification: Added import-support tests; `swift test`, `swift build`.

### Flashcard bottom labels could not be turned off
- Symptom: Every exported flashcard always included the vocabulary word at the bottom, even when a label-free card was desired.
- Fix: Added a Show/Hide radio control for labels, reflected the choice in previews, and passed the setting into PPTX export so the text shape is omitted when labels are hidden.
- Verification: Added a PPTX exporter test for label omission; `swift test`, `swift build`, packaged app launch.

### Extra image-search terms could not be added manually
- Symptom: The image picker only searched words extracted from the imported lesson plan, so users could not add a related term like `sunscreen`.
- Fix: Added a manual search-term field with a `+` button. Custom terms are added to the reviewed word list and become Google Images tabs during image picking.
- Verification: `swift test`, `swift build`, packaged app launch.

### Export filename was always `Vocabulary Flashcards`
- Symptom: The save panel always started from the same generic deck name.
- Fix: Added a file-name field in the toolbar and used it as the default PPTX save name, automatically adding `.pptx` when needed.
- Verification: `swift test`, `swift build`, packaged app launch.

## 2026-06-18

### Picked clipart was pixelated/blotchy in the exported PowerPoint
- Symptom: Clicking a Google Images result imported the tiny ~150px `gstatic` thumbnail. Trimming and upscaling that low-res source to fill a slide left flashcards blotchy.
- Fix: The picker JS now reads the larger preview/source image from the thumbnail's enclosing `<a href="/imgres?...imgurl=...">` anchor and passes both it and the grid thumbnail to Swift. `downloadImageData` downloads **both candidates in parallel and keeps whichever decodes to the bigger image**, falling back to the thumbnail if the bigger one fails. Downloads now use a real desktop Safari `User-Agent` + `Accept`/`Referer` headers (the old `ClipartBrowser/1.0` UA was getting 403'd by stock sites, which had silently forced the small-thumbnail fallback). The webview also uses that UA so Google serves the standard Images layout. The imported size is shown in the status bar for verification.
- Verification: `swift test`, `swift build`, packaged app launch; status bar reports the larger pixel size and the Upscaler Preview "Original" panel matches.

### Embedded Google Images grid showed only a few huge thumbnails
- Symptom: After switching the web view to a desktop Safari `User-Agent` (needed for reliable image quality), Google served its desktop Images layout, which renders very large thumbnails — so only one or two images were visible at a time and the grid was hard to browse.
- Fix: Added a zoom control (−/＋ buttons with a percentage readout) to the image-browser toolbar that drives `WKWebView.pageZoom`. Defaults to 60% so many thumbnails are visible at once, persists via `@AppStorage`, and updates the web view live.
- Verification: `swift build`, packaged app launch; confirmed more thumbnails visible and zoom adjusts the grid density.

### Image grid stopped loading after ~34 picks (couldn't pick more)
- Symptom: After picking many cards in one session, the embedded Google Images grid went blank (empty thumbnails) and further picks did nothing.
- Diagnosis: Added file-based debug logging (`DebugLog` → `debuglog.md`, truncated each launch) instrumenting the pick → download → import pipeline. The log showed all 34 imports succeeding with `isImporting` correctly reset every time — the import code never hung. No further `JS message received` events arrived, meaning the web view itself stopped rendering: the WKWebView web-content process is terminated/throttled after many rapid full-page Google reloads, leaving a blank grid.
- Fix: Implemented `webViewWebContentProcessDidTerminate` to log and auto-reload the web view, added navigation-outcome logging (didFinish/didFail/HTTP ≥ 400), a 15s per-request download timeout (so a slow host can't wedge picking), and a manual Reload button in the image-browser toolbar for when the grid stalls.
- Verification: `swift build`, packaged app launch; debug log confirms the import pipeline stays healthy and now records navigation/process-termination events.

### Embedded Google web view reloaded again and again
- Symptom: After the grid stalled (Google throttling the session), the web view began reloading repeatedly on its own.
- Diagnosis: `GoogleImageBrowser.updateNSView` reloaded whenever `webView.url != tab.searchURL`. Google rewrites/redirects the search URL immediately (and to a consent/"sorry" page once throttled), so that comparison stayed true and every SwiftUI re-render triggered another load — an endless loop, compounded by the crash auto-reload.
- Fix: Load each tab's search exactly once, keyed by tab id (`Coordinator.loadedTabID`), instead of comparing URLs. Debounced `webViewWebContentProcessDidTerminate` auto-reload (min 10s apart) so a crash→reload→crash sequence can't spin. Manual Reload button and per-tab navigation still work.
- Verification: `swift build`, `swift test`, packaged app launch; debug log shows ~one `nav didFinish` per tab instead of a reload flood.

### Added a numbered slide-label list export (.txt / .docx)
- Request: Export a list of slide numbers with their word labels, e.g. `1 - Tall` / `2 - Short`, as a text or Word file.
- Implementation: `WordListExporter` (core) builds the numbered, title-cased list as plain text or a minimal Word-compatible `.docx` (OOXML via ZIPFoundation). Added an "Export List" toolbar button with a save panel offering `.txt` or `.docx`; the extension chooses the format. Order follows the flashcard/slide order.
- Verification: Added `WordListExporterTests` (text format + docx is a valid zip containing the lines); `swift test`, `swift build`, packaged app launch.

### Added Baidu as a selectable image search engine
- Request: Offer Baidu image search alongside Google, selectable via a control, keeping all picking mechanics (big image, upscaler, etc.).
- Implementation: `ImageSearchEngine` enum (google/baidu) in core with per-engine `searchURL(for:)` (`BaiduImagesSearch` uses `image.baidu.com/search/index?tn=baiduimage&word=...`). Added a segmented Google/Baidu picker in the image-browser toolbar (persisted via `@AppStorage`). The picker JS is now universal: it extracts the full-size image from Google's `imgurl` anchor OR Baidu's `data-objurl` item, with the thumbnail as fallback — so the existing bigger-of-two download, trimming, and upscaler all apply unchanged. Web view loads are keyed on (tab, engine) so switching engines reloads the current search without re-introducing the reload loop.
- Verification: `swift build`, `swift test`, packaged app launch.
