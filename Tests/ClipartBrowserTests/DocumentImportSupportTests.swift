import Foundation
import XCTest
@testable import ClipartBrowserCore

final class DocumentImportSupportTests: XCTestCase {
    func testAcceptsDocumentsAndImagesForImport() {
        XCTAssertTrue(DocumentImportSupport.isSupportedImportURL(URL(fileURLWithPath: "/tmp/lesson.docx")))
        XCTAssertTrue(DocumentImportSupport.isSupportedImportURL(URL(fileURLWithPath: "/tmp/lesson.pdf")))
        XCTAssertTrue(DocumentImportSupport.isSupportedImportURL(URL(fileURLWithPath: "/tmp/lesson.rtf")))
        XCTAssertTrue(DocumentImportSupport.isSupportedImportURL(URL(fileURLWithPath: "/tmp/lesson.jpg")))
        XCTAssertTrue(DocumentImportSupport.isSupportedImportURL(URL(fileURLWithPath: "/tmp/lesson.heic")))
    }

    func testRejectsUnsupportedFilesForImport() {
        XCTAssertFalse(DocumentImportSupport.isSupportedImportURL(URL(fileURLWithPath: "/tmp/slides.pptx")))
        XCTAssertFalse(DocumentImportSupport.isSupportedImportURL(URL(fileURLWithPath: "/tmp/archive.zip")))
    }
}
