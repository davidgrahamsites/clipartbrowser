import AppKit
import Foundation
import ImageIO
import PDFKit
import Vision
import ZIPFoundation

public enum DocumentTextExtractor {
    public static func extractText(from url: URL) throws -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "docx":
            return try extractDOCXText(from: url)
        case "pdf":
            return try extractPDFText(from: url)
        case "rtf", "rtfd":
            return try extractAttributedText(from: url)
        default:
            if DocumentImportSupport.isImagePathExtension(pathExtension) {
                return try extractImageText(from: url)
            }
            return try String(contentsOf: url, encoding: .utf8)
        }
    }
}

public enum DocumentTextExtractionError: Error {
    case missingDOCXDocumentXML
    case unreadableDOCXDocumentXML
    case unreadablePDF
    case unreadableImage
}

private extension DocumentTextExtractor {
    static func extractDOCXText(from url: URL) throws -> String {
        let archive = try Archive(url: url, accessMode: .read)
        guard let entry = archive["word/document.xml"] else {
            throw DocumentTextExtractionError.missingDOCXDocumentXML
        }

        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }

        let parserDelegate = DOCXDocumentTextParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw DocumentTextExtractionError.unreadableDOCXDocumentXML
        }

        return parserDelegate.text
    }

    static func extractPDFText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw DocumentTextExtractionError.unreadablePDF
        }

        return (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
    }

    static func extractAttributedText(from url: URL) throws -> String {
        let attributedString = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
        return attributedString.string
    }

    static func extractImageText(from url: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw DocumentTextExtractionError.unreadableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        return (request.results ?? [])
            .sorted { first, second in
                if abs(first.boundingBox.midY - second.boundingBox.midY) > 0.015 {
                    return first.boundingBox.midY > second.boundingBox.midY
                }
                return first.boundingBox.minX < second.boundingBox.minX
            }
            .compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private final class DOCXDocumentTextParser: NSObject, XMLParserDelegate {
    private var buffer = ""
    private var isCapturingText = false

    var text: String {
        buffer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch localName(elementName) {
        case "t":
            isCapturingText = true
        case "tab":
            buffer.append("\t")
        case "br", "cr":
            appendLineBreakIfNeeded()
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCapturingText else { return }
        buffer.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch localName(elementName) {
        case "t":
            isCapturingText = false
        case "p":
            appendLineBreakIfNeeded()
        default:
            break
        }
    }

    private func appendLineBreakIfNeeded() {
        guard !buffer.hasSuffix("\n") else { return }
        buffer.append("\n")
    }

    private func localName(_ name: String) -> String {
        String(name.split(separator: ":").last ?? Substring(name))
    }
}
