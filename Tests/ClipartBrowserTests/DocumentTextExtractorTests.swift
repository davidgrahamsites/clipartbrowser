import AppKit
import Foundation
import XCTest
import ZIPFoundation
@testable import ClipartBrowserCore

final class DocumentTextExtractorTests: XCTestCase {
    func testExtractsPlainTextDocument() throws {
        let url = temporaryURL(extension: "txt")
        try "Vocabulary Words: apple, banana".write(to: url, atomically: true, encoding: .utf8)

        let text = try DocumentTextExtractor.extractText(from: url)

        XCTAssertEqual(text, "Vocabulary Words: apple, banana")
    }

    func testExtractsDOCXParagraphTextInOrder() throws {
        let url = temporaryURL(extension: "docx")
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>Vocabulary Words</w:t></w:r></w:p>
            <w:p><w:r><w:t>1. apple - a fruit</w:t></w:r></w:p>
            <w:p><w:r><w:t>2. banana</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """
        let archive = try Archive(accessMode: .create)
        try archive.addEntry(
            with: "word/document.xml",
            type: .file,
            uncompressedSize: Int64(Data(xml.utf8).count),
            compressionMethod: .deflate
        ) { position, size in
            let data = Data(xml.utf8)
            let start = Int(position)
            guard start < data.count else { return Data() }
            return data.subdata(in: start..<min(start + size, data.count))
        }
        try XCTUnwrap(archive.data).write(to: url)

        let text = try DocumentTextExtractor.extractText(from: url)

        XCTAssertTrue(text.contains("Vocabulary Words\n1. apple - a fruit\n2. banana"))
    }

    func testExtractsTextFromImageDocument() throws {
        let url = temporaryURL(extension: "png")
        try makeTextImageData("Vocabulary Words\napple\nbanana", fileType: .png).write(to: url)

        let text = try DocumentTextExtractor.extractText(from: url)

        XCTAssertTrue(text.localizedCaseInsensitiveContains("Vocabulary"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("apple"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("banana"))
    }

    func testExtractsTextFromJPEGImageDocument() throws {
        let url = temporaryURL(extension: "jpg")
        try makeTextImageData("Key Words\nsummer\nwater", fileType: .jpeg).write(to: url)

        let text = try DocumentTextExtractor.extractText(from: url)

        XCTAssertTrue(text.localizedCaseInsensitiveContains("Key Words"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("summer"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("water"))
    }
}

private func makeTextImageData(_ text: String, fileType: NSBitmapImageRep.FileType) throws -> Data {
    let size = NSSize(width: 1200, height: 700)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 96, weight: .bold),
        .foregroundColor: NSColor.black,
        .paragraphStyle: paragraph
    ]
    text.draw(in: NSRect(x: 80, y: 120, width: 1040, height: 500), withAttributes: attributes)
    image.unlockFocus()

    let tiffData = try XCTUnwrap(image.tiffRepresentation)
    let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
    return try XCTUnwrap(bitmap.representation(using: fileType, properties: [:]))
}

private func temporaryURL(extension pathExtension: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(pathExtension)
}
