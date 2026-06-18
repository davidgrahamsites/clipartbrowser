import Foundation
import XCTest
@testable import ClipartBrowserCore

final class ImageSearchTests: XCTestCase {
    func testSearchPrefersResultsThatMatchVocabularyTerm() async throws {
        let service = ClipartImageSearchService(providers: [
            StubImageProvider(results: [
                result(id: "boat", title: "House boat", imageURL: "https://example.com/house-boat.png"),
                result(id: "bedroom", title: "Bedroom interior clipart", imageURL: "https://example.com/bedroom-interior.png")
            ])
        ])

        let results = try await service.searchImages(for: "bedroom", limit: 10)

        XCTAssertEqual(results.map(\.id), ["bedroom"])
    }

    func testNextImageSkipsAlreadyTriedResults() async throws {
        let service = ClipartImageSearchService(providers: [
            StubImageProvider(results: [
                result(id: "apple-1", title: "Apple clipart", imageURL: "https://example.com/apple-1.png"),
                result(id: "apple-2", title: "Apple drawing", imageURL: "https://example.com/apple-2.png")
            ]),
            StubImageProvider(results: [
                result(id: "apple-3", title: "Apple icon", imageURL: "https://example.org/apple-3.png")
            ])
        ])

        let next = try await service.nextImage(for: "apple", excludingResultIDs: ["apple-1"])

        XCTAssertEqual(next?.id, "apple-2")
    }

    func testSearchFiltersDecorativePatternsAndHolidayGreetingCards() async throws {
        let service = ClipartImageSearchService(providers: [
            StubImageProvider(results: [
                result(id: "pattern", title: "Rainbow chevron seamless pattern", imageURL: "https://example.com/go-pattern.png"),
                result(id: "greeting", title: "St Patrick's Day greetings card", imageURL: "https://example.com/wait-greeting-card.png"),
                result(id: "go", title: "Go action arrow clipart", imageURL: "https://example.com/go-action-arrow.png")
            ])
        ])

        let results = try await service.searchImages(for: "go", limit: 10)

        XCTAssertEqual(results.map(\.id), ["go"])
    }

    func testRoomTermsSearchForInteriorScenesInsteadOfSingleFurnitureObjects() async throws {
        let service = ClipartImageSearchService(providers: [
            QueryAwareStubImageProvider { query in
                if query.contains("interior") {
                    return [
                        result(id: "scene", title: "Living room interior scene", imageURL: "https://example.com/living-room-interior.png")
                    ]
                }
                return [
                    result(id: "couch", title: "Living room sofa", imageURL: "https://example.com/living-room-sofa.png")
                ]
            }
        ])

        let results = try await service.searchImages(for: "living room", limit: 10)

        XCTAssertEqual(results.map(\.id), ["scene"])
    }

    func testBedroomRejectsBedOnlySubstitutesWhenInteriorSceneExists() async throws {
        let service = ClipartImageSearchService(providers: [
            StubImageProvider(results: [
                result(id: "bed", title: "Bedroom bed clipart", imageURL: "https://example.com/bedroom-bed.png"),
                result(id: "interior", title: "Bedroom interior scene", imageURL: "https://example.com/bedroom-interior.png")
            ])
        ])

        let results = try await service.searchImages(for: "bedroom", limit: 10)

        XCTAssertEqual(results.map(\.id), ["interior"])
    }

    func testGeneralTermsUseFallbackQueryVariants() async throws {
        let service = ClipartImageSearchService(providers: [
            QueryAwareStubImageProvider { query in
                if query.contains("simple illustration") {
                    return [
                        result(id: "leaf", title: "Leaf simple illustration", imageURL: "https://example.com/leaf.png")
                    ]
                }
                return []
            }
        ])

        let results = try await service.searchImages(for: "leaf", limit: 10)

        XCTAssertEqual(results.map(\.id), ["leaf"])
    }
}

private struct StubImageProvider: ClipartImageProviding {
    let results: [ClipartImageResult]

    func searchImages(for term: String, limit: Int) async throws -> [ClipartImageResult] {
        Array(results.prefix(limit))
    }
}

private struct QueryAwareStubImageProvider: ClipartImageProviding {
    let results: @Sendable (String) -> [ClipartImageResult]

    func searchImages(for term: String, limit: Int) async throws -> [ClipartImageResult] {
        Array(results(term).prefix(limit))
    }
}

private func result(id: String, title: String, imageURL: String) -> ClipartImageResult {
    ClipartImageResult(
        id: id,
        title: title,
        imageURL: URL(string: imageURL)!,
        sourceName: "Stub"
    )
}
