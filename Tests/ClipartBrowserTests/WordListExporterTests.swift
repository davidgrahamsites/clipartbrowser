import XCTest
import ZIPFoundation
@testable import ClipartBrowserCore

final class WordListExporterTests: XCTestCase {
    func testTextNumbersAndTitleCasesEachWord() {
        let text = WordListExporter.text(for: ["tall", "short", "bridge building"])
        XCTAssertEqual(text, "1 - Tall\n2 - Short\n3 - Bridge Building")
    }

    func testDOCXIsAValidZipContainingTheNumberedLines() throws {
        let data = try WordListExporter.makeDOCX(for: ["tall", "short"])
        let archive = try Archive(data: data, accessMode: .read)

        XCTAssertNotNil(archive["[Content_Types].xml"])
        let documentEntry = try XCTUnwrap(archive["word/document.xml"])

        var xml = Data()
        _ = try archive.extract(documentEntry) { xml.append($0) }
        let documentXML = try XCTUnwrap(String(data: xml, encoding: .utf8))

        XCTAssertTrue(documentXML.contains("1 - Tall"))
        XCTAssertTrue(documentXML.contains("2 - Short"))
    }
}
