import Foundation
import XCTest
@testable import ClipartBrowserCore

final class GoogleImagesSearchTests: XCTestCase {
    func testBuildsGoogleImagesURLForClipartQuery() throws {
        let url = GoogleImagesSearch.url(for: "living room")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items: [URLQueryItem] = components.queryItems ?? []
        let queryItems = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/search")
        XCTAssertEqual(queryItems["tbm"], "isch")
        XCTAssertEqual(queryItems["q"], "living room clipart")
    }
}
