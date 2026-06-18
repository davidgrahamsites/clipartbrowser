import AppKit
import Foundation
import XCTest
import ZIPFoundation
@testable import ClipartBrowserCore

final class PowerPointExporterTests: XCTestCase {
    func testCreatesLetterPortraitPPTXWithOneSlidePerFlashcard() throws {
        let image = try makeTestPNG(width: 2, height: 2) { _, _ in .systemBlue }
        let data = try PowerPointExporter.makePPTX(
            slides: [
                FlashcardSlide(word: "apple", imageData: image),
                FlashcardSlide(word: "banana", imageData: image)
            ],
            paddingPixels: 12
        )
        let archive = try Archive(data: data, accessMode: .read)

        XCTAssertNotNil(archive["[Content_Types].xml"])
        XCTAssertNotNil(archive["ppt/slides/slide1.xml"])
        XCTAssertNotNil(archive["ppt/slides/slide2.xml"])
        XCTAssertNotNil(archive["ppt/media/image1.png"])

        let presentationXML = try String(decoding: archive.data(for: "ppt/presentation.xml"), as: UTF8.self)
        XCTAssertTrue(presentationXML.contains("cx=\"7772400\""))
        XCTAssertTrue(presentationXML.contains("cy=\"10058400\""))
        XCTAssertTrue(presentationXML.contains("type=\"letter\""))
    }

    func testCreatesLetterLandscapePPTXWhenRequested() throws {
        let image = try makeTestPNG(width: 2, height: 2) { _, _ in .systemGreen }
        let data = try PowerPointExporter.makePPTX(
            slides: [
                FlashcardSlide(word: "apple", imageData: image)
            ],
            paddingPixels: 12,
            orientation: .landscape
        )
        let archive = try Archive(data: data, accessMode: .read)

        let presentationXML = try String(decoding: archive.data(for: "ppt/presentation.xml"), as: UTF8.self)
        XCTAssertTrue(presentationXML.contains("cx=\"10058400\""))
        XCTAssertTrue(presentationXML.contains("cy=\"7772400\""))
        XCTAssertTrue(presentationXML.contains("type=\"letter\""))

        let appXML = try String(decoding: archive.data(for: "docProps/app.xml"), as: UTF8.self)
        XCTAssertTrue(appXML.contains("<PresentationFormat>Letter Landscape</PresentationFormat>"))
    }

    func testOmitsBottomTextLabelWhenRequested() throws {
        let image = try makeTestPNG(width: 2, height: 2) { _, _ in .systemPurple }
        let data = try PowerPointExporter.makePPTX(
            slides: [
                FlashcardSlide(word: "water", imageData: image)
            ],
            paddingPixels: 12,
            showsTextLabel: false
        )
        let archive = try Archive(data: data, accessMode: .read)

        let slideXML = try String(decoding: archive.data(for: "ppt/slides/slide1.xml"), as: UTF8.self)
        XCTAssertFalse(slideXML.contains("<a:t>water</a:t>"))
        XCTAssertFalse(slideXML.contains("name=\"Word\""))
    }
}

private extension Archive {
    func data(for path: String) throws -> Data {
        let entry = try XCTUnwrap(self[path])
        var data = Data()
        _ = try extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }
}
