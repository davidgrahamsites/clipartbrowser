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

### Added Bing and Yandex image search engines
- Request: Add Bing (and Yandex, which is accessible in China) as image search engines with the same picking mechanics.
- Implementation: Extended `ImageSearchEngine` with `bing` and `yandex` (+ `BingImagesSearch`/`YandexImagesSearch` URLs). The universal picker JS now also extracts full-size images from Bing's `a.iusc` `m` JSON (`murl`/`turl`) and Yandex's `.serp-item` `data-bem` JSON (`img_href`/`preview`). The engine picker became a compact dropdown (Google/Baidu/Bing/Yandex). Bigger-of-two download, trimming, and upscaling are unchanged.
- Verification: `swift build`, `swift test`, packaged app launch.

## 2026-06-21 (Windows edition + release + licensing)

### Windows installer build failed in CI (electron-builder)
- Symptom: `electron-builder` aborted in GitHub Actions. Logs were unreadable via the API until `gh` was authenticated.
- Causes + fixes (in order found): (1) `⨯ Cannot detect repository by .git/config` → added `repository` to `windows/package.json` and `build.publish: null` + `--publish never`. (2) `Env WIN_CSC_LINK is not correct` from an **empty** code-signing secret → moved signing into a guarded step that only sets `CSC_LINK` when `WINDOWS_CERT_BASE64` is present.
- Verification: green `windows-build.yml` runs producing the NSIS `.exe`.

### `fetch-builds.sh` deleted a local installer on a network timeout
- Symptom: After refreshing local installers, `builds/` had only the Chinese `.exe` — the English one was gone.
- Cause: the script ran `rm -f builds/*.exe` up front, then the English `gh` download timed out, leaving that edition missing (the English build itself was fine — published as the `v0.2.0` release).
- Fix: download each installer to a temp dir and only `mv` into `builds/` on success, with 3 retries; never delete up front.
- Verification: re-downloaded the English `v0.2.0` installer into `builds/`; `bash -n`.

### Re-pointed release tag attached a stale asset
- Symptom: The `v0.2.0-zh` GitHub Release briefly carried both a `0.1.0` and `0.2.0` installer.
- Cause: the tag first landed on the pre-version-bump commit (built `0.1.0`); re-pointing it triggered a second build while the stale one also published.
- Fix: deleted the stray `0.1.0` asset with `gh release delete-asset`; release now has only the correct licensed `0.2.0` installer.

## 2026-06-22 (Windows editions: licensing share + import/Defender triage)

### Windows ZH edition never asked for license activation (EN and ZH shared one license store)
- Symptom: With both editions installed on the same machine, only the English app prompted for a key; the Chinese app launched straight into the UI without activating. Raised the question of whether the ZH key mechanism was broken.
- Diagnosis: NOT a key-mechanism bug. At runtime Electron derives `app.getPath("userData")` from `app.getName()`, which reads the **top-level** `productName`/`name` of the bundled `package.json` — it ignores `build.productName` (that only names the installer/exe). Both editions had an identical top-level `name` (`clipartbrowser-windows`) and no top-level `productName`, so both resolved userData to `%APPDATA%/clipartbrowser-windows` and shared the same `license.json` (and localStorage). The machine-locked key EN wrote there verified fine for ZH too (same machine fingerprint), so ZH saw a valid license and skipped activation. Verified by probing a real `package.json` under Electron: `app.getName()` → `clipartbrowser-windows`; adding top-level `productName` flipped userData to a distinct folder.
- Fix: gave each edition a distinct runtime identity via a **top-level** `productName` — EN (`main`) `"ClipartBrowser"`, ZH (`zh-CN`) `"ClipartBrowser CN"`. Each edition now uses its own `%APPDATA%/<productName>` folder, so they activate (and store prefs) independently; the same per-computer key still activates both. Bumped EN → 0.2.2 (ZH mirrors as 0.2.2-zh). Note: existing 0.2.0/0.2.1 EN installs move to a new userData folder and must re-activate once (same key works).

### Windows import did not populate the word list — root cause: heading detection too strict
- Report: Importing a `.docx` (via the Import button or drag-and-drop) left the word list empty in both editions.
- Investigation: Ran the real `src/index.html` + `renderer.js` under Electron, both from source and from a packed `app.asar`. The pipeline itself is sound — a doc whose heading is exactly `Vocabulary`/`Word Bank`/etc. populates fine. Reproduced the empty list by building realistic Word-style docx variants: a **title-like heading** such as `Unit 5 Vocabulary` or `Week 3 Spelling Words` was NOT recognized (the matcher required the heading line to equal a known phrase exactly), so the section never started and zero words were found ("No vocabulary section detected"). This was a shared limitation — the macOS extractor did the same — not a Windows-only regression.
- Fix: broadened `isVocabularyHeading` to also accept short, title-like lines that END WITH a known heading phrase (e.g. `Unit 5 Vocabulary`), where the qualifier before the phrase is light — ≤2 words or containing a number (Unit 5, Week 3, Lesson 2). Ordinary sentences that merely end in "vocabulary" are still rejected (prefix too long / no number), as is a document with no heading at all. Implemented on the macOS source of truth first (`VocabularyExtractor.swift` + 3 new tests) then ported identically to `windows/src/lib/vocabulary.js` (+ `test-logic.js` cases). Verified end-to-end: the `Unit 5 Vocabulary` docx now yields its words through the real importer. win-zh inherits via merge.

### Windows Defender / SmartScreen blocked the ZH installer on first launch
- Report: The Chinese installer was blocked by Windows Defender on the first attempt, then installed on the second.
- Diagnosis: Expected behavior for an **unsigned** NSIS installer — SmartScreen shows "Windows protected your PC" until the user clicks "More info → Run anyway" (the successful "second attempt"). Not a code defect. The CI signing step is guarded and only runs when a `WINDOWS_CERT_BASE64` secret is present; no cert is configured, so all installers ship unsigned. Permanent fix is code signing (Authenticode/EV cert) — out of scope here; documented as the cause.
