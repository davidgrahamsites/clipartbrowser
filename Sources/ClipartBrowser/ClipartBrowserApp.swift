import AppKit
import ClipartBrowserCore
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@main
struct ClipartBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            UpscalerPreviewCommands()
        }

        Window("Upscaler Preview", id: UpscalerPreviewView.windowID) {
            UpscalerPreviewView()
                .environmentObject(UpscalerPreviewCenter.shared)
                .frame(minWidth: 760, minHeight: 520)
        }
    }
}

private struct UpscalerPreviewCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("View") {
            Button("Show Upscaler Preview") {
                openWindow(id: UpscalerPreviewView.windowID)
            }
            .keyboardShortcut("u", modifiers: [.command, .shift])
        }
    }
}

private struct ContentView: View {
    @State private var words: [WordReviewItem] = []
    @State private var flashcards: [FlashcardPreview] = []
    @State private var issues: [ProcessingIssue] = []
    @State private var status = "Import a document to find vocabulary words."
    @State private var importedFileName: String?
    @State private var exportFileName = "Vocabulary Flashcards"
    @State private var paddingPixels = 12.0
    @State private var outputOrientation: PowerPointSlideOrientation = .portrait
    @State private var textLabelMode: TextLabelMode = .show
    @State private var resizeMethod: ImageResizeMethod = .coreImage
    @AppStorage("imageSearchEngine") private var searchEngine: ImageSearchEngine = .google
    @State private var isImporting = false
    @State private var isImportingBrowserImage = false
    @State private var imageBrowserSession: ImageBrowserSession?
    @State private var selectedBrowserTabID: UUID?
    @State private var isDropTargeted = false
    @State private var selectedFlashcardID: UUID?

    private var selectedWords: [WordReviewItem] {
        words.filter(\.isIncluded)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                WordReviewPane(words: $words, importedFileName: importedFileName)
                    .frame(minWidth: 300, idealWidth: 360)
                VStack(spacing: 0) {
                    if let imageBrowserSession {
                        ImageBrowserPane(
                            session: imageBrowserSession,
                            selectedTabID: $selectedBrowserTabID,
                            searchEngine: $searchEngine,
                            isImporting: isImportingBrowserImage,
                            onImagePicked: importPickedBrowserImage,
                            onPreviousTab: { moveBrowserTab(by: -1) },
                            onNextTab: { moveBrowserTab(by: 1) },
                            onClose: closeImageBrowser
                        )
                        .frame(minHeight: 420)
                        Divider()
                    }

                    FlashcardReviewPane(
                        flashcards: flashcards,
                        issues: issues,
                        isWorking: isImportingBrowserImage,
                        paddingPixels: paddingPixels,
                        outputOrientation: outputOrientation,
                        showsTextLabel: textLabelMode.showsTextLabel,
                        selectedFlashcardID: $selectedFlashcardID,
                        onRetry: retryImage,
                        onRemove: removeFlashcard
                    )
                }
                .frame(minWidth: 520)
            }
            Divider()
            statusBar
        }
        .onChange(of: selectedFlashcardID) { _, _ in updateUpscalerPreview() }
        .onChange(of: flashcards) { _, _ in updateUpscalerPreview() }
        .onChange(of: paddingPixels) { _, _ in updateUpscalerPreview() }
        .onChange(of: outputOrientation) { _, _ in updateUpscalerPreview() }
        .onChange(of: textLabelMode) { _, _ in updateUpscalerPreview() }
        .overlay {
            if isDropTargeted {
                DropTargetOverlay()
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDroppedFileProviders)
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    importDocument()
                } label: {
                    Label("Import", systemImage: "doc.badge.plus")
                }
                .disabled(isImporting || isImportingBrowserImage)

                Button {
                    pickImages()
                } label: {
                    Label("Pick Images", systemImage: "photo.on.rectangle")
                }
                .disabled(selectedWords.isEmpty || isImporting || isImportingBrowserImage)

                Button {
                    exportPPTX()
                } label: {
                    Label("Export PPTX", systemImage: "square.and.arrow.up")
                }
                .disabled(flashcards.isEmpty || isImportingBrowserImage)

                Button {
                    exportWordList()
                } label: {
                    Label("Export List", systemImage: "list.number")
                }
                .disabled(flashcards.isEmpty || isImportingBrowserImage)
                .help("Export a numbered list of slide labels as .txt or .docx")

                Spacer()

                HStack(spacing: 6) {
                    Text("File")
                        .foregroundStyle(.secondary)
                    TextField("File name", text: $exportFileName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                }
            }

            HStack(spacing: 14) {
                HStack(spacing: 8) {
                    Text("Padding")
                        .foregroundStyle(.secondary)
                    Slider(value: $paddingPixels, in: 0...72, step: 1)
                        .frame(width: 160)
                    TextField("px", value: $paddingPixels, format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 52)
                    Text("px")
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 20)

                Picker("Orientation", selection: $outputOrientation) {
                    ForEach(PowerPointSlideOrientation.allCases) { orientation in
                        Text(orientation.displayName)
                            .tag(orientation)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                Divider()
                    .frame(height: 20)

                HStack(spacing: 6) {
                    Text("Labels")
                        .foregroundStyle(.secondary)
                    Picker("Labels", selection: $textLabelMode) {
                        ForEach(TextLabelMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 120)
                }

                Divider()
                    .frame(height: 20)

                HStack(spacing: 6) {
                    Text("Upscaler")
                        .foregroundStyle(.secondary)
                    Picker("Upscaler", selection: $resizeMethod) {
                        ForEach(ImageResizeMethod.allCases) { method in
                            Text(method.displayName)
                                .tag(method)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                Spacer()
            }
        }
        .padding(12)
        .background(.bar)
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if isImporting || isImportingBrowserImage {
                ProgressView()
                    .controlSize(.small)
            }
            Text(status)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(selectedWords.count) selected")
                .foregroundStyle(.secondary)
            Text("\(flashcards.count) cards")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @MainActor
    private func importDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .plainText,
            .pdf,
            .rtf,
            UTType(filenameExtension: "rtfd") ?? .rtf,
            UTType(filenameExtension: "docx") ?? .data,
            .image
        ]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await loadDocument(from: url)
        }
    }

    @MainActor
    private func loadDocument(from url: URL) async {
        isImporting = true
        importedFileName = url.lastPathComponent
        status = "Extracting text from \(url.lastPathComponent)..."
        defer { isImporting = false }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let text = try await Task.detached {
                try DocumentTextExtractor.extractText(from: url)
            }.value
            let candidates = VocabularyExtractor.extractCandidates(from: text)
            words = candidates.map {
                WordReviewItem(id: $0.id, term: $0.term, sourceLine: $0.sourceLine, isIncluded: true)
            }
            flashcards = []
            issues = []
            closeImageBrowser()
            status = candidates.isEmpty
                ? "No vocabulary section was found in \(url.lastPathComponent)."
                : "Found \(candidates.count) vocabulary words. Review them before picking images."
        } catch {
            words = []
            flashcards = []
            issues = []
            closeImageBrowser()
            status = "Could not import \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func handleDroppedFileProviders(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        Task {
            await importFirstSupportedDroppedFile(from: fileProviders)
        }
        return true
    }

    private func importFirstSupportedDroppedFile(from providers: [NSItemProvider]) async {
        for provider in providers {
            guard let url = await droppedFileURL(from: provider),
                  DocumentImportSupport.isSupportedImportURL(url)
            else {
                continue
            }

            await loadDocument(from: url)
            return
        }

        await MainActor.run {
            status = "Drop a supported document or image file."
        }
    }

    private func droppedFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                continuation.resume(returning: Self.fileURL(from: item))
            }
        }
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let data = item as? NSData {
            return URL(dataRepresentation: data as Data, relativeTo: nil)
        }

        if let string = item as? String {
            return URL(string: string) ?? URL(fileURLWithPath: string)
        }

        return nil
    }

    @MainActor
    private func pickImages() {
        let terms = selectedWords
        guard !terms.isEmpty else { return }

        openImageBrowser(for: terms.map(\.term), replacingFlashcardID: nil)
    }

    @MainActor
    private func retryImage(for flashcard: FlashcardPreview) {
        openImageBrowser(for: [flashcard.word], replacingFlashcardID: flashcard.id)
    }

    @MainActor
    private func openImageBrowser(for words: [String], replacingFlashcardID: UUID?) {
        let tabs = words.map { ImageSearchTab(word: $0) }
        guard let firstTab = tabs.first else { return }

        imageBrowserSession = ImageBrowserSession(tabs: tabs, replacingFlashcardID: replacingFlashcardID)
        selectedBrowserTabID = firstTab.id
        DebugLog.log("openImageBrowser tabs=\(tabs.count) replacing=\(replacingFlashcardID != nil) firstTab=\(firstTab.word)")
        status = replacingFlashcardID == nil
            ? "Choose images from the Google Images tabs."
            : "Choose a replacement image for \(firstTab.word)."
    }

    @MainActor
    private func closeImageBrowser() {
        imageBrowserSession = nil
        selectedBrowserTabID = nil
    }

    @MainActor
    private func moveBrowserTab(by offset: Int) {
        guard let session = imageBrowserSession,
              let selectedBrowserTabID,
              let currentIndex = session.tabs.firstIndex(where: { $0.id == selectedBrowserTabID })
        else {
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), session.tabs.count - 1)
        self.selectedBrowserTabID = session.tabs[nextIndex].id
        status = "Choose an image for \(session.tabs[nextIndex].word)."
    }

    @MainActor
    private func importPickedBrowserImage(_ image: PickedBrowserImage) {
        let tabMatch = image.tabID == selectedBrowserTabID
        DebugLog.log("pick received word=\(image.word) tabMatch=\(tabMatch) isImporting=\(isImportingBrowserImage) cards=\(flashcards.count)")
        guard tabMatch, !isImportingBrowserImage else {
            DebugLog.log("pick IGNORED word=\(image.word) reason=\(tabMatch ? "alreadyImporting" : "tabMismatch")")
            return
        }

        Task {
            await importBrowserImage(image)
        }
    }

    @MainActor
    private func importBrowserImage(_ image: PickedBrowserImage) async {
        isImportingBrowserImage = true
        status = "Importing image for \(image.word)..."
        DebugLog.log("import START word=\(image.word)")
        defer {
            isImportingBrowserImage = false
            DebugLog.log("import END word=\(image.word) isImporting reset")
        }

        let result = ClipartImageResult(
            id: "google-\(image.imageURL.absoluteString)",
            title: image.title?.isEmpty == false ? image.title! : image.word,
            imageURL: image.imageURL,
            thumbnailURL: image.thumbnailURL,
            landingPageURL: image.pageURL,
            sourceName: "Google Images"
        )

        do {
            let download = try await downloadImageData(for: result)
            let rawData = download.data
            let trimmed = ImageTrimmer.trimmedPNGData(from: rawData) ?? rawData
            let target = PowerPointExporter.fittedImagePixelSize(
                imageData: trimmed,
                paddingPixels: paddingPixels,
                orientation: outputOrientation,
                showsTextLabel: textLabelMode.showsTextLabel
            )
            let imageData = ImageUpscaler.resized(trimmed, to: target, using: resizeMethod) ?? trimmed
            let previewID = imageBrowserSession?.replacingFlashcardID
                ?? flashcards.first(where: { $0.word.caseInsensitiveCompare(image.word) == .orderedSame })?.id
                ?? UUID()
            let preview = FlashcardPreview(
                id: previewID,
                word: image.word,
                imageData: imageData,
                sourceImageData: trimmed,
                source: result,
                candidateResults: [result]
            )

            if let index = flashcards.firstIndex(where: { $0.id == previewID }) {
                flashcards[index] = preview
            } else {
                flashcards.append(preview)
            }

            DebugLog.log("import OK word=\(image.word) chosen=\(Int(download.pixelSize.width))x\(Int(download.pixelSize.height)) cards=\(flashcards.count)")
            status = "Added image for \(image.word) — \(Int(download.pixelSize.width))×\(Int(download.pixelSize.height))px."
            moveBrowserTabAfterImporting(tabID: image.tabID)
        } catch {
            DebugLog.log("import FAIL word=\(image.word) error=\(error.localizedDescription)")
            status = "Could not import image for \(image.word): \(error.localizedDescription)"
        }
    }

    @MainActor
    private func moveBrowserTabAfterImporting(tabID: UUID) {
        guard let session = imageBrowserSession,
              let currentIndex = session.tabs.firstIndex(where: { $0.id == tabID })
        else {
            DebugLog.log("advanceTab NO_SESSION_OR_TAB")
            return
        }

        let nextIndex = currentIndex + 1
        if nextIndex < session.tabs.count {
            selectedBrowserTabID = session.tabs[nextIndex].id
            DebugLog.log("advanceTab from #\(currentIndex) to #\(nextIndex) word=\(session.tabs[nextIndex].word) selected=\(session.tabs[nextIndex].id)")
            status = "Choose an image for \(session.tabs[nextIndex].word)."
        } else if session.replacingFlashcardID != nil {
            closeImageBrowser()
        } else {
            DebugLog.log("advanceTab END_OF_TABS at #\(currentIndex)")
            status = "Picked \(flashcards.count) images. Review cards before exporting."
        }
    }

    /// Downloads both candidate images Google offers — the larger preview/source
    /// image and the small grid thumbnail — and keeps whichever decodes to the
    /// bigger picture. If the bigger candidate fails (e.g. a 403 from a stock
    /// site), the thumbnail is used, so the result is never worse than before.
    private func downloadImageData(for result: ClipartImageResult) async throws -> DownloadedImage {
        let referer = result.landingPageURL?.absoluteString
        DebugLog.log("download START primary=\(result.imageURL.host ?? "?") thumb=\(result.thumbnailURL?.host ?? "none")")

        async let primary = decodedImage(from: result.imageURL, label: "primary", referer: referer)
        async let fallback: DownloadedImage? = {
            guard let thumbnailURL = result.thumbnailURL else { return nil }
            return await decodedImage(from: thumbnailURL, label: "thumb", referer: referer)
        }()

        let candidates = [await primary, await fallback].compactMap { $0 }
        if let best = candidates.max(by: { $0.pixelArea < $1.pixelArea }) {
            DebugLog.log("download DONE candidates=\(candidates.count) chose=\(Int(best.pixelSize.width))x\(Int(best.pixelSize.height))")
            return best
        }
        // Nothing decoded; surface a real error by attempting the primary directly.
        DebugLog.log("download NO_DECODE retrying primary directly")
        let data = try await downloadData(from: result.imageURL, referer: referer)
        return DownloadedImage(data: data, pixelSize: pixelSize(of: data) ?? .zero)
    }

    /// Downloads `url` and decodes it; returns `nil` if the request fails or the
    /// bytes aren't a valid image.
    private func decodedImage(from url: URL, label: String, referer: String?) async -> DownloadedImage? {
        let start = Date()
        do {
            let data = try await downloadData(from: url, referer: referer)
            guard let size = pixelSize(of: data) else {
                DebugLog.log("dl \(label) NOT_IMAGE host=\(url.host ?? "?") bytes=\(data.count) t=\(elapsedMS(start))ms")
                return nil
            }
            DebugLog.log("dl \(label) OK host=\(url.host ?? "?") \(Int(size.width))x\(Int(size.height)) bytes=\(data.count) t=\(elapsedMS(start))ms")
            return DownloadedImage(data: data, pixelSize: size)
        } catch {
            DebugLog.log("dl \(label) FAIL host=\(url.host ?? "?") error=\(error.localizedDescription) t=\(elapsedMS(start))ms")
            return nil
        }
    }

    private func elapsedMS(_ start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1000)
    }

    private func pixelSize(of data: Data) -> CGSize? {
        guard let cgImage = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0, cgImage.height > 0
        else {
            return nil
        }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    private func downloadData(from url: URL, referer: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(clipartBrowserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        // Bound each request so a slow/hung host can't permanently block picking.
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppError.badHTTPStatus(httpResponse.statusCode)
        }
        return data
    }

    @MainActor
    private func exportPPTX() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pptx") ?? .data]
        panel.nameFieldStringValue = exportFileNameWithExtension

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let slides = flashcards.map {
                FlashcardSlide(word: $0.word, imageData: $0.imageData, imageExtension: "png")
            }
            let data = try PowerPointExporter.makePPTX(
                slides: slides,
                paddingPixels: paddingPixels,
                orientation: outputOrientation,
                showsTextLabel: textLabelMode.showsTextLabel
            )
            try data.write(to: url, options: .atomic)
            status = "Exported \(url.lastPathComponent)."
        } catch {
            status = "Could not export PPTX: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func exportWordList() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "docx") ?? .data]
        panel.nameFieldStringValue = "\(exportBaseName) Word List.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let words = flashcards.map(\.word)
        do {
            if url.pathExtension.lowercased() == "docx" {
                try WordListExporter.makeDOCX(for: words).write(to: url, options: .atomic)
            } else {
                try Data(WordListExporter.text(for: words).utf8).write(to: url, options: .atomic)
            }
            status = "Exported \(url.lastPathComponent)."
        } catch {
            status = "Could not export word list: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func removeFlashcard(_ flashcard: FlashcardPreview) {
        flashcards.removeAll { $0.id == flashcard.id }
        if selectedFlashcardID == flashcard.id { selectedFlashcardID = nil }
        status = "Removed \(flashcard.word)."
    }

    /// Pushes the currently selected card (or the most recent, if none is
    /// selected) into the shared center so the Upscaler Preview window can
    /// compare every method on its un-upscaled source.
    @MainActor
    private func updateUpscalerPreview() {
        let card = flashcards.first(where: { $0.id == selectedFlashcardID }) ?? flashcards.last
        guard let card else {
            UpscalerPreviewCenter.shared.request = nil
            return
        }
        let target = PowerPointExporter.fittedImagePixelSize(
            imageData: card.sourceImageData,
            paddingPixels: paddingPixels,
            orientation: outputOrientation,
            showsTextLabel: textLabelMode.showsTextLabel
        )
        UpscalerPreviewCenter.shared.request = UpscalerPreviewRequest(
            cardID: card.id,
            word: card.word,
            sourceImageData: card.sourceImageData,
            targetSize: target
        )
    }

    private var exportBaseName: String {
        let trimmed = exportFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Vocabulary Flashcards" : trimmed
    }

    private var exportFileNameWithExtension: String {
        let baseName = exportBaseName
        return baseName.lowercased().hasSuffix(".pptx") ? baseName : "\(baseName).pptx"
    }
}

private struct WordReviewPane: View {
    @Binding var words: [WordReviewItem]
    let importedFileName: String?
    @State private var customTerm = ""

    private var cleanedCustomTerm: String {
        customTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAddCustomTerm: Bool {
        let term = cleanedCustomTerm
        guard !term.isEmpty else { return false }
        return !words.contains { $0.term.caseInsensitiveCompare(term) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Words")
                    .font(.title2.bold())
                Text(importedFileName ?? "No document imported")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            HStack(spacing: 8) {
                TextField("Add search term", text: $customTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCustomTerm)

                Button(action: addCustomTerm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(!canAddCustomTerm)
                .help("Add a custom image-search word")
            }
            .padding(.horizontal, 14)

            if words.isEmpty {
                ContentUnavailableView("No Words", systemImage: "text.badge.plus", description: Text("Import a document with a vocabulary section."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List($words) { $word in
                    Toggle(isOn: $word.isIncluded) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.term)
                                .font(.body)
                            Text(word.sourceLine > 0 ? "Line \(word.sourceLine)" : "Manual")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }

    private func addCustomTerm() {
        let term = cleanedCustomTerm
        guard canAddCustomTerm else { return }

        words.append(WordReviewItem(term: term, sourceLine: 0, isIncluded: true))
        customTerm = ""
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

private struct DropTargetOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.accentColor.opacity(0.10))
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 7]))
                .padding(18)
            VStack(spacing: 10) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48, weight: .semibold))
                Text("Drop to Import")
                    .font(.title3.bold())
            }
            .foregroundStyle(Color.accentColor)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ImageBrowserPane: View {
    let session: ImageBrowserSession
    @Binding var selectedTabID: UUID?
    @Binding var searchEngine: ImageSearchEngine
    let isImporting: Bool
    let onImagePicked: @MainActor (PickedBrowserImage) -> Void
    let onPreviousTab: @MainActor () -> Void
    let onNextTab: @MainActor () -> Void
    let onClose: @MainActor () -> Void

    @AppStorage("imageBrowserZoom") private var browserZoom: Double = 0.6
    @State private var reloadToken = 0
    private let minZoom = 0.3
    private let maxZoom = 1.0

    private var selectedTab: ImageSearchTab? {
        if let selectedTabID,
           let tab = session.tabs.first(where: { $0.id == selectedTabID }) {
            return tab
        }
        return session.tabs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onPreviousTab) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("Previous image search")

                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(session.tabs) { tab in
                            ImageSearchTabButton(
                                title: tab.word,
                                isSelected: tab.id == selectedTabID
                            ) {
                                selectedTabID = tab.id
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                Button(action: onNextTab) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("Next image search")

                Divider()
                    .frame(height: 22)

                if isImporting {
                    ProgressView()
                        .controlSize(.small)
                }

                Divider()
                    .frame(height: 22)

                Picker("Search engine", selection: $searchEngine) {
                    ForEach(ImageSearchEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 110)
                .help("Choose which image search engine to use")

                Divider()
                    .frame(height: 22)

                Button {
                    reloadToken += 1
                    DebugLog.log("manual reload requested token=\(reloadToken)")
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("Reload images (use if the grid stops loading)")

                Divider()
                    .frame(height: 22)

                HStack(spacing: 4) {
                    Button {
                        browserZoom = max(minZoom, (browserZoom - 0.1).rounded(toPlaces: 1))
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(browserZoom <= minZoom)
                    .help("Zoom out to show more images")

                    Text("\(Int((browserZoom * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38)

                    Button {
                        browserZoom = min(maxZoom, (browserZoom + 0.1).rounded(toPlaces: 1))
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(browserZoom >= maxZoom)
                    .help("Zoom in to show fewer, larger images")
                }

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("Close image browser")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if let selectedTab {
                GoogleImageBrowser(tab: selectedTab, engine: searchEngine, pageZoom: browserZoom, reloadToken: reloadToken, onImagePicked: onImagePicked)
            } else {
                ContentUnavailableView("No Search", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ImageSearchTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: 150)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .background {
            if isSelected {
                Capsule()
                    .fill(.quaternary)
            }
        }
    }
}

private struct GoogleImageBrowser: NSViewRepresentable {
    let tab: ImageSearchTab
    let engine: ImageSearchEngine
    let pageZoom: Double
    let reloadToken: Int
    let onImagePicked: @MainActor (PickedBrowserImage) -> Void

    private var searchURL: URL { engine.searchURL(for: tab.word) }
    private var loadKey: String { "\(tab.id.uuidString)-\(engine.rawValue)" }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, onImagePicked: onImagePicked)
    }

    func makeNSView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "clipartImagePicker")
        contentController.addUserScript(WKUserScript(source: Self.selectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = clipartBrowserUserAgent
        webView.pageZoom = CGFloat(pageZoom)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: searchURL))
        context.coordinator.loadedKey = loadKey
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.tab = tab
        context.coordinator.onImagePicked = onImagePicked

        if webView.pageZoom != CGFloat(pageZoom) {
            webView.pageZoom = CGFloat(pageZoom)
        }

        if reloadToken != context.coordinator.lastReloadToken {
            context.coordinator.lastReloadToken = reloadToken
            webView.reload()
            return
        }

        // Load a tab's search exactly once per (tab, engine). Comparing against
        // webView.url would reload on every SwiftUI update once the engine
        // rewrites/redirects the URL. Switching engine changes loadKey and reloads.
        if context.coordinator.loadedKey != loadKey {
            context.coordinator.loadedKey = loadKey
            webView.load(URLRequest(url: searchURL))
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "clipartImagePicker")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var tab: ImageSearchTab
        var onImagePicked: @MainActor (PickedBrowserImage) -> Void
        var lastReloadToken = 0
        var loadedKey: String?
        var lastAutoReload: Date?

        init(tab: ImageSearchTab, onImagePicked: @escaping @MainActor (PickedBrowserImage) -> Void) {
            self.tab = tab
            self.onImagePicked = onImagePicked
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            DebugLog.log("JS message received name=\(message.name) tab=\(tab.word)")
            guard message.name == "clipartImagePicker",
                  let payload = message.body as? [String: Any],
                  let imageURLString = payload["imageURL"] as? String,
                  let imageURL = URL(string: imageURLString),
                  imageURL.scheme?.hasPrefix("http") == true
            else {
                DebugLog.log("JS message DROPPED tab=\(tab.word) (no usable imageURL)")
                return
            }

            let thumbnailURL = (payload["thumbnailURL"] as? String).flatMap(URL.init(string:))
            let pageURL = (payload["pageURL"] as? String).flatMap(URL.init(string:))
            let title = payload["title"] as? String
            let image = PickedBrowserImage(
                tabID: tab.id,
                word: tab.word,
                imageURL: imageURL,
                thumbnailURL: thumbnailURL,
                pageURL: pageURL,
                title: title
            )

            Task { @MainActor in
                onImagePicked(image)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DebugLog.log("nav didFinish host=\(webView.url?.host ?? "?")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DebugLog.log("nav didFail error=\(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DebugLog.log("nav didFailProvisional error=\(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let http = navigationResponse.response as? HTTPURLResponse, http.statusCode >= 400 {
                DebugLog.log("nav response status=\(http.statusCode) host=\(http.url?.host ?? "?")")
            }
            decisionHandler(.allow)
        }

        /// The web-content process can be killed (memory/throttling) after many
        /// reloads, leaving a blank grid. Reload once to auto-recover, but debounce
        /// so a crash→reload→crash sequence can't spin.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            let now = Date()
            if let last = lastAutoReload, now.timeIntervalSince(last) < 10 {
                DebugLog.log("WEBCONTENT TERMINATED — skipping auto-reload (debounced)")
                return
            }
            lastAutoReload = now
            DebugLog.log("WEBCONTENT TERMINATED — auto-reloading")
            webView.reload()
        }
    }

    private static let selectionScript = """
    (function() {
        if (window.__clipartBrowserImagePickerInstalled) { return; }
        window.__clipartBrowserImagePickerInstalled = true;

        function firstImageFrom(node) {
            if (!node) { return null; }
            if (node.tagName === 'IMG') { return node; }
            if (node.closest) {
                var nearbyImage = node.closest('img');
                if (nearbyImage) { return nearbyImage; }
                var link = node.closest('a');
                if (link && link.querySelector) { return link.querySelector('img'); }
            }
            if (node.querySelector) { return node.querySelector('img'); }
            return null;
        }

        function httpOnly(value) {
            if (!value) { return null; }
            if (value.indexOf('data:') === 0 || value.indexOf('blob:') === 0) { return null; }
            if (value.indexOf('http') !== 0) { return null; }
            return value;
        }

        // Google Images wraps every thumbnail in an <a href="/imgres?...imgurl=FULL...">.
        // The imgurl param is the full-resolution original the preview pane shows.
        function fullImageFromImgres(node) {
            if (!node || !node.closest) { return null; }
            var anchor = node.closest('a[href*="imgurl="]');
            if (!anchor) {
                var container = node.closest('[data-ved]') || node.parentElement;
                if (container && container.querySelector) {
                    anchor = container.querySelector('a[href*="imgurl="]');
                }
            }
            if (!anchor || !anchor.href) { return null; }
            try {
                var url = new URL(anchor.href, window.location.href);
                var imgurl = url.searchParams.get('imgurl');
                var imgrefurl = url.searchParams.get('imgrefurl');
                return {
                    imageURL: httpOnly(imgurl ? decodeURIComponent(imgurl) : null),
                    pageURL: imgrefurl ? decodeURIComponent(imgrefurl) : null
                };
            } catch (e) {
                return null;
            }
        }

        // Baidu Images stores the full original on the grid item as data-objurl
        // (and a usable thumbnail as data-thumburl).
        function fullImageFromBaidu(node) {
            if (!node || !node.closest) { return null; }
            var item = node.closest('[data-objurl]') || node.closest('[data-thumburl]');
            if (!item) { return null; }
            return {
                imageURL: httpOnly(item.getAttribute('data-objurl')),
                thumbnailURL: httpOnly(item.getAttribute('data-thumburl')),
                pageURL: item.getAttribute('data-fromurl') || null
            };
        }

        // Bing wraps each result in <a class="iusc" m='{"murl":FULL,"turl":THUMB,...}'>.
        function fullImageFromBing(node) {
            if (!node || !node.closest) { return null; }
            var a = node.closest('a.iusc') || node.closest('a[m]');
            if (!a) { return null; }
            var m = a.getAttribute('m');
            if (!m) { return null; }
            try {
                var data = JSON.parse(m);
                return {
                    imageURL: httpOnly(data.murl),
                    thumbnailURL: httpOnly(data.turl),
                    pageURL: data.purl || null
                };
            } catch (e) { return null; }
        }

        // Yandex stores a JSON blob on each .serp-item in data-bem; the full image
        // is serp-item.img_href, with preview thumbnails under serp-item.preview.
        function fullImageFromYandex(node) {
            if (!node || !node.closest) { return null; }
            var item = node.closest('.serp-item[data-bem]') || node.closest('[data-bem]');
            if (!item) { return null; }
            var bem = item.getAttribute('data-bem');
            if (!bem) { return null; }
            try {
                var si = (JSON.parse(bem) || {})['serp-item'];
                if (!si) { return null; }
                var thumb = (si.preview && si.preview.length) ? si.preview[0].url : null;
                var full = si.img_href || (si.dups && si.dups.length ? si.dups[0].url : null);
                return {
                    imageURL: httpOnly(full),
                    thumbnailURL: httpOnly(thumb),
                    pageURL: (si.snippet && si.snippet.url) || null
                };
            } catch (e) { return null; }
        }

        function pickImageFrom(event) {
            var image = firstImageFrom(event.target);
            if (!image) { return; }

            var source = fullImageFromImgres(image) || fullImageFromBaidu(image) ||
                fullImageFromBing(image) || fullImageFromYandex(image);

            var thumb = httpOnly(image.currentSrc || image.src ||
                image.getAttribute('data-src') || image.getAttribute('data-iurl') ||
                image.getAttribute('data-ou')) || (source && source.thumbnailURL) || null;

            var full = source && source.imageURL;
            var imageURL = full || thumb;
            if (!imageURL) { return; }

            event.preventDefault();
            event.stopPropagation();

            var link = image.closest ? image.closest('a') : null;
            var pageURL = (source && source.pageURL) ||
                (link && link.href ? link.href : window.location.href);

            window.webkit.messageHandlers.clipartImagePicker.postMessage({
                imageURL: imageURL,
                thumbnailURL: (thumb && thumb !== imageURL) ? thumb : null,
                pageURL: pageURL,
                title: image.alt || image.title || document.title || ''
            });
        }

        document.addEventListener('click', pickImageFrom, true);
    })();
    """
}

private struct FlashcardReviewPane: View {
    let flashcards: [FlashcardPreview]
    let issues: [ProcessingIssue]
    let isWorking: Bool
    let paddingPixels: Double
    let outputOrientation: PowerPointSlideOrientation
    let showsTextLabel: Bool
    @Binding var selectedFlashcardID: UUID?
    let onRetry: (FlashcardPreview) -> Void
    let onRemove: (FlashcardPreview) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Flashcards")
                        .font(.title2.bold())
                    Text("\(outputOrientation.displayName) letter export, \(Int(paddingPixels)) px padding, \(showsTextLabel ? "labels on" : "labels off")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 180)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            if flashcards.isEmpty && issues.isEmpty {
                ContentUnavailableView("No Cards", systemImage: "photo.stack", description: Text("Pick images after reviewing words."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(flashcards) { flashcard in
                            FlashcardCard(
                                flashcard: flashcard,
                                isRetrying: false,
                                isSelected: flashcard.id == selectedFlashcardID,
                                outputOrientation: outputOrientation,
                                showsTextLabel: showsTextLabel,
                                onSelect: { selectedFlashcardID = flashcard.id },
                                onRetry: onRetry,
                                onRemove: onRemove
                            )
                        }

                        ForEach(issues) { issue in
                            IssueCard(issue: issue)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
}

private struct FlashcardCard: View {
    let flashcard: FlashcardPreview
    let isRetrying: Bool
    let isSelected: Bool
    let outputOrientation: PowerPointSlideOrientation
    let showsTextLabel: Bool
    let onSelect: () -> Void
    let onRetry: (FlashcardPreview) -> Void
    let onRemove: (FlashcardPreview) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(.white)

                VStack(spacing: 0) {
                    Group {
                        if let image = NSImage(data: flashcard.imageData) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    if showsTextLabel {
                        Text(flashcard.word)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .padding(.horizontal, 10)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                cardActionButton(
                    systemImage: "trash",
                    tint: .red,
                    help: "Remove \(flashcard.word)",
                    action: { onRemove(flashcard) }
                )
                .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                cardActionButton(
                    systemImage: isRetrying ? "hourglass" : "arrow.clockwise",
                    tint: .blue,
                    help: isRetrying ? "Finding another image..." : "Find a different image",
                    action: { onRetry(flashcard) }
                )
                .padding(8)
            }
            .aspectRatio(outputOrientation.previewAspectRatio, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.quaternary, lineWidth: 1)
            )

            Text(flashcard.word)
                .font(.headline)
                .lineLimit(1)
            Text(sourceLine(for: flashcard.source))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(.background)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color(.quaternaryLabelColor),
                        lineWidth: isSelected ? 2.5 : 1)
        )
        .contentShape(.rect(cornerRadius: 8))
        .onTapGesture(perform: onSelect)
        .help("Click to preview upscaler methods for \(flashcard.word)")
    }

    private func cardActionButton(
        systemImage: String,
        tint: Color,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isRetrying)
        .help(help)
    }

    private func sourceLine(for source: ClipartImageResult) -> String {
        if let license = source.license, !license.isEmpty {
            return "\(source.sourceName), \(license)"
        }
        return source.sourceName
    }
}

private struct IssueCard: View {
    let issue: ProcessingIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(issue.word)
                .font(.headline)
            Text(issue.message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(12)
        .background(.background)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct WordReviewItem: Identifiable, Equatable {
    let id: UUID
    var term: String
    let sourceLine: Int
    var isIncluded: Bool

    init(id: UUID = UUID(), term: String, sourceLine: Int, isIncluded: Bool) {
        self.id = id
        self.term = term
        self.sourceLine = sourceLine
        self.isIncluded = isIncluded
    }
}

private enum TextLabelMode: String, CaseIterable, Identifiable {
    case show
    case hide

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .show:
            return "Show"
        case .hide:
            return "Hide"
        }
    }

    var showsTextLabel: Bool {
        self == .show
    }
}

private struct ImageBrowserSession: Identifiable, Equatable {
    let id = UUID()
    let tabs: [ImageSearchTab]
    let replacingFlashcardID: UUID?
}

private struct ImageSearchTab: Identifiable, Equatable {
    let id = UUID()
    let word: String
}

private struct PickedBrowserImage: Identifiable, Equatable {
    let id = UUID()
    let tabID: UUID
    let word: String
    let imageURL: URL
    let thumbnailURL: URL?
    let pageURL: URL?
    let title: String?
}

private extension PowerPointSlideOrientation {
    var previewAspectRatio: CGFloat {
        switch self {
        case .portrait:
            return 8.5 / 11.0
        case .landscape:
            return 11.0 / 8.5
        }
    }
}

private struct FlashcardPreview: Identifiable, Equatable {
    let id: UUID
    let word: String
    let imageData: Data
    /// The trimmed, pre-upscale image. Kept so the Upscaler Preview can re-run
    /// every resize method live for comparison.
    let sourceImageData: Data
    let source: ClipartImageResult
    let candidateResults: [ClipartImageResult]
    let attemptedResultIDs: Set<String>
    let attemptedImageURLs: Set<String>

    init(
        id: UUID = UUID(),
        word: String,
        imageData: Data,
        sourceImageData: Data? = nil,
        source: ClipartImageResult,
        candidateResults: [ClipartImageResult] = [],
        attemptedResultIDs: Set<String> = [],
        attemptedImageURLs: Set<String> = []
    ) {
        self.id = id
        self.word = word
        self.imageData = imageData
        self.sourceImageData = sourceImageData ?? imageData
        self.source = source
        self.candidateResults = candidateResults

        var resultIDs = attemptedResultIDs
        resultIDs.insert(source.id)
        self.attemptedResultIDs = resultIDs

        var imageURLs = attemptedImageURLs
        imageURLs.insert(source.imageURL.absoluteString)
        self.attemptedImageURLs = imageURLs
    }

    func replacingImage(imageData: Data, sourceImageData: Data? = nil, source: ClipartImageResult) -> FlashcardPreview {
        FlashcardPreview(
            id: id,
            word: word,
            imageData: imageData,
            sourceImageData: sourceImageData,
            source: source,
            candidateResults: candidateResults,
            attemptedResultIDs: attemptedResultIDs,
            attemptedImageURLs: attemptedImageURLs
        )
    }
}

private struct ProcessingIssue: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let message: String
}

/// A desktop Safari User-Agent so Google serves its standard Images layout and so
/// image hosts don't reject the request as a bot.
private let clipartBrowserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15"

/// A downloaded image plus its decoded pixel size, used to pick the bigger of the
/// candidate images for a result.
private struct DownloadedImage {
    let data: Data
    let pixelSize: CGSize

    var pixelArea: CGFloat { pixelSize.width * pixelSize.height }
}

private enum AppError: LocalizedError {
    case badHTTPStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badHTTPStatus(let status):
            return "Image download failed with HTTP \(status)."
        }
    }
}

// MARK: - Upscaler Preview

/// What the Upscaler Preview window should compare: a single card's un-upscaled
/// source image and the pixel size it will occupy on the slide.
struct UpscalerPreviewRequest: Equatable {
    let cardID: UUID
    let word: String
    let sourceImageData: Data
    let targetSize: CGSize
}

/// Bridges the main window's current selection to the separate preview window.
@MainActor
final class UpscalerPreviewCenter: ObservableObject {
    static let shared = UpscalerPreviewCenter()
    @Published var request: UpscalerPreviewRequest?
    private init() {}
}

private enum PreviewZoom: String, CaseIterable, Identifiable {
    case fit, oneX, twoX, fourX

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fit: return "Fit"
        case .oneX: return "100%"
        case .twoX: return "200%"
        case .fourX: return "400%"
        }
    }

    var scale: CGFloat? {
        switch self {
        case .fit: return nil
        case .oneX: return 1
        case .twoX: return 2
        case .fourX: return 4
        }
    }
}

/// One rendered variant: the original plus each resize method's result.
/// Carries PNG `Data` (Sendable) so it can be produced off the main actor;
/// the `NSImage` is materialized in the view.
private struct UpscaledVariant: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let imageData: Data?
    let pixelSize: CGSize

    var image: NSImage? { imageData.flatMap(NSImage.init(data:)) }
}

struct UpscalerPreviewView: View {
    static let windowID = "upscaler-preview"

    @EnvironmentObject private var center: UpscalerPreviewCenter
    @State private var variants: [UpscaledVariant] = []
    @State private var isRendering = false
    @State private var zoom: PreviewZoom = .fit

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .task(id: center.request) { await render() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Upscaler Preview")
                    .font(.title3.bold())
                if let request = center.request {
                    Text("“\(request.word)” · target \(Int(request.targetSize.width))×\(Int(request.targetSize.height)) px")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Select a flashcard in the main window to compare methods.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isRendering {
                ProgressView().controlSize(.small)
            }
            Picker("Zoom", selection: $zoom) {
                ForEach(PreviewZoom.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 230)
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        if center.request == nil {
            ContentUnavailableView(
                "No Card Selected",
                systemImage: "rectangle.on.rectangle.angled",
                description: Text("Click a flashcard to see how each upscaler handles it.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(variants) { variant in
                        variantCell(variant)
                    }
                }
                .padding(16)
            }
        }
    }

    private func variantCell(_ variant: UpscaledVariant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Rectangle().fill(.white)
                imageView(for: variant)
            }
            .frame(height: 260)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary, lineWidth: 1))

            Text(variant.title).font(.headline)
            Text(variant.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("\(Int(variant.pixelSize.width))×\(Int(variant.pixelSize.height)) px")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func imageView(for variant: UpscaledVariant) -> some View {
        if let image = variant.image {
            if let scale = zoom.scale {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: variant.pixelSize.width * scale,
                               height: variant.pixelSize.height * scale)
                }
            } else {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(8)
            }
        } else {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }

    private func render() async {
        guard let request = center.request else {
            variants = []
            return
        }
        isRendering = true
        defer { isRendering = false }

        let source = request.sourceImageData
        let target = request.targetSize

        let rendered: [UpscaledVariant] = await Task.detached(priority: .userInitiated) {
            func pixelSize(of data: Data?) -> CGSize {
                guard let data,
                      let cg = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else { return .zero }
                return CGSize(width: cg.width, height: cg.height)
            }

            var result: [UpscaledVariant] = []
            result.append(UpscaledVariant(
                id: "original",
                title: "Original",
                subtitle: "Trimmed source, before upscaling",
                imageData: source,
                pixelSize: pixelSize(of: source)
            ))

            for method in ImageResizeMethod.allCases {
                let data = ImageUpscaler.resized(source, to: target, using: method) ?? source
                result.append(UpscaledVariant(
                    id: method.rawValue,
                    title: method.displayName,
                    subtitle: "\(method.technicalName) · \(method.summary)",
                    imageData: data,
                    pixelSize: pixelSize(of: data)
                ))
            }
            return result
        }.value

        variants = rendered
    }
}
