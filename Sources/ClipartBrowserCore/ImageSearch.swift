import Foundation

public struct ClipartImageResult: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let imageURL: URL
    public let thumbnailURL: URL?
    public let landingPageURL: URL?
    public let license: String?
    public let creator: String?
    public let sourceName: String

    public init(
        id: String,
        title: String,
        imageURL: URL,
        thumbnailURL: URL? = nil,
        landingPageURL: URL? = nil,
        license: String? = nil,
        creator: String? = nil,
        sourceName: String
    ) {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.landingPageURL = landingPageURL
        self.license = license
        self.creator = creator
        self.sourceName = sourceName
    }
}

public protocol ClipartImageProviding: Sendable {
    func searchImages(for term: String, limit: Int) async throws -> [ClipartImageResult]
}

public struct ClipartImageSearchService: Sendable {
    private let providers: [any ClipartImageProviding]

    public init(providers: [any ClipartImageProviding] = [OpenverseImageProvider(), WikimediaCommonsImageProvider()]) {
        self.providers = providers
    }

    public func firstImage(for term: String) async throws -> ClipartImageResult? {
        try await searchImages(for: term, limit: 1).first
    }

    public func nextImage(for term: String, excludingResultIDs: Set<String>) async throws -> ClipartImageResult? {
        try await searchImages(for: term, limit: 24).first { result in
            !excludingResultIDs.contains(result.id)
        }
    }

    public func searchImages(for term: String, limit: Int) async throws -> [ClipartImageResult] {
        var allResults: [ClipartImageResult] = []
        var lastError: Error?
        let profile = SearchProfile(term: term)
        let providerLimit = max(limit, 12)

        for query in profile.queries {
            for provider in providers {
                do {
                    allResults.append(contentsOf: try await provider.searchImages(for: query, limit: providerLimit))
                } catch {
                    lastError = error
                }
            }
        }

        if allResults.isEmpty, let lastError {
            throw lastError
        }

        return Array(rankedResults(allResults, for: profile).prefix(max(1, limit)))
    }
}

private extension ClipartImageSearchService {
    func rankedResults(_ results: [ClipartImageResult], for profile: SearchProfile) -> [ClipartImageResult] {
        let termTokens = profile.termTokens
        guard !termTokens.isEmpty else {
            return deduplicated(results)
        }

        let candidates = deduplicated(results).filter {
            !isDecorativeOrTextHeavyAsset($0) && !isRejected($0, by: profile)
        }
        let scored = candidates.enumerated().map { index, result in
            ScoredResult(
                result: result,
                score: relevanceScore(for: result, profile: profile),
                originalIndex: index
            )
        }

        let matchingResults = scored.filter { $0.score > 0 }
        let sortableResults = matchingResults.isEmpty ? scored : matchingResults

        return sortableResults
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.originalIndex < $1.originalIndex
            }
            .map(\.result)
    }

    func deduplicated(_ results: [ClipartImageResult]) -> [ClipartImageResult] {
        var seenURLs = Set<String>()
        var seenIDs = Set<String>()
        var uniqueResults: [ClipartImageResult] = []

        for result in results {
            let normalizedURL = result.imageURL.absoluteString.lowercased()
            guard !seenURLs.contains(normalizedURL), !seenIDs.contains(result.id) else { continue }
            seenURLs.insert(normalizedURL)
            seenIDs.insert(result.id)
            uniqueResults.append(result)
        }

        return uniqueResults
    }

    func relevanceScore(for result: ClipartImageResult, profile: SearchProfile) -> Int {
        let titleTokens = Set(significantTokens(in: result.title))
        let urlTokens = Set(significantTokens(in: result.imageURL.absoluteString))
        let landingTokens = Set(significantTokens(in: result.landingPageURL?.absoluteString ?? ""))
        let creatorTokens = Set(significantTokens(in: result.creator ?? ""))

        var score = 0
        for token in profile.termTokens {
            if titleTokens.contains(token) {
                score += 30
            }
            if urlTokens.contains(token) {
                score += 18
            }
            if landingTokens.contains(token) {
                score += 10
            }
            if creatorTokens.contains(token) {
                score += 4
            }
        }

        let searchableTokens = titleTokens.union(urlTokens).union(landingTokens).union(creatorTokens)
        if profile.termTokens.allSatisfy(searchableTokens.contains) {
            score += 40
        }
        score += profile.preferredSceneTokens.intersection(searchableTokens).count * 24
        score -= sourcePenalty(for: result)

        return score
    }

    func sourcePenalty(for result: ClipartImageResult) -> Int {
        let source = result.sourceName.lowercased()
        if source.contains("flickr") {
            return 18
        }
        if source.contains("rawpixel") {
            return 10
        }
        return 0
    }

    func isDecorativeOrTextHeavyAsset(_ result: ClipartImageResult) -> Bool {
        let text = [
            result.title,
            result.imageURL.absoluteString,
            result.landingPageURL?.absoluteString ?? ""
        ]
            .joined(separator: " ")
            .lowercased()

        return Self.rejectedResultPhrases.contains { text.contains($0) }
    }

    func isRejected(_ result: ClipartImageResult, by profile: SearchProfile) -> Bool {
        let tokens = Set(significantTokens(in: searchableText(for: result)))

        if !profile.rejectedTokens.isDisjoint(with: tokens) {
            return true
        }

        let hasObjectSubstitute = !profile.objectSubstituteTokens.isDisjoint(with: tokens)
        let hasSceneCue = !profile.preferredSceneTokens.isDisjoint(with: tokens)
        if hasObjectSubstitute && !hasSceneCue {
            return true
        }

        if profile.requiresSceneCue && !hasSceneCue {
            return true
        }

        return false
    }

    func searchableText(for result: ClipartImageResult) -> String {
        [
            result.title,
            result.imageURL.absoluteString,
            result.landingPageURL?.absoluteString ?? "",
            result.creator ?? ""
        ].joined(separator: " ")
    }

    func significantTokens(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { token in
                token.count > 1 && !Self.ignoredSearchTokens.contains(token)
            }
    }

    static var ignoredSearchTokens: Set<String> {
        [
            "clip",
            "clipart",
            "commons",
            "drawing",
            "file",
            "icon",
            "image",
            "illustration",
            "jpg",
            "jpeg",
            "org",
            "png",
            "public",
            "svg",
            "the",
            "upload",
            "wiki",
            "wikimedia",
            "wikipedia"
        ]
    }

    static var rejectedResultPhrases: Set<String> {
        [
            "background",
            "border",
            "christmas",
            "easter",
            "fabric",
            "greeting",
            "greetings",
            "halloween",
            "holiday",
            "invitation",
            "pattern",
            "poster",
            "saint patrick",
            "seamless",
            "st patrick",
            "texture",
            "wallpaper",
            "waterproof"
        ]
    }
}

private struct ScoredResult {
    let result: ClipartImageResult
    let score: Int
    let originalIndex: Int
}

private struct SearchProfile {
    let originalTerm: String
    let queries: [String]
    let termTokens: [String]
    let objectSubstituteTokens: Set<String>
    let preferredSceneTokens: Set<String>
    let rejectedTokens: Set<String>
    let requiresSceneCue: Bool

    init(term: String) {
        let normalized = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.originalTerm = term
        self.termTokens = normalized
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        switch normalized {
        case "living room":
            self.queries = [
                "living room interior scene",
                "living room interior illustration",
                "living room furniture scene"
            ]
            self.objectSubstituteTokens = ["couch", "sofa", "loveseat", "settee"]
            self.preferredSceneTokens = ["apartment", "home", "house", "inside", "interior", "scene"]
            self.rejectedTokens = []
            self.requiresSceneCue = true
        case "bedroom":
            self.queries = [
                "bedroom interior scene",
                "bedroom room illustration",
                "bedroom furniture scene"
            ]
            self.objectSubstituteTokens = ["bed", "bedding", "mattress", "pillow", "pillows"]
            self.preferredSceneTokens = ["furniture", "inside", "interior", "room", "scene"]
            self.rejectedTokens = []
            self.requiresSceneCue = true
        case "room":
            self.queries = [
                "room interior scene",
                "empty room interior illustration",
                "room furniture scene"
            ]
            self.objectSubstituteTokens = []
            self.preferredSceneTokens = ["empty", "furniture", "inside", "interior", "scene"]
            self.rejectedTokens = ["dress", "dressing", "fashion", "girl", "lady", "makeup", "people", "person", "salon", "vintage", "woman"]
            self.requiresSceneCue = true
        case "roof":
            self.queries = [
                "house roof clipart",
                "roof on house illustration",
                "home roof clipart"
            ]
            self.objectSubstituteTokens = []
            self.preferredSceneTokens = ["building", "home", "house"]
            self.rejectedTokens = ["asian", "chinese", "japanese", "ornament", "ornamental", "pagoda", "temple"]
            self.requiresSceneCue = true
        default:
            self.queries = [
                "\(term) clipart",
                "\(term) simple illustration"
            ]
            self.objectSubstituteTokens = []
            self.preferredSceneTokens = []
            self.rejectedTokens = []
            self.requiresSceneCue = false
        }
    }
}

public struct OpenverseImageProvider: ClipartImageProviding {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func searchImages(for term: String, limit: Int) async throws -> [ClipartImageResult] {
        var components = URLComponents(string: "https://api.openverse.org/v1/images/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "page_size", value: String(max(1, min(limit, 20)))),
            URLQueryItem(name: "mature", value: "false")
        ]

        let response = try await decoded(OpenverseResponse.self, from: components.url!)
        return response.results.compactMap { item in
            guard let imageURL = URL(string: item.url) else { return nil }
            return ClipartImageResult(
                id: "openverse-\(item.id)",
                title: item.title ?? term,
                imageURL: imageURL,
                thumbnailURL: item.thumbnail.flatMap(URL.init(string:)),
                landingPageURL: item.foreignLandingURL.flatMap(URL.init(string:)),
                license: item.license,
                creator: item.creator,
                sourceName: item.source ?? "Openverse"
            )
        }
    }

    private func decoded<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response: response)
        return try JSONDecoder().decode(type, from: data)
    }
}

public struct WikimediaCommonsImageProvider: ClipartImageProviding {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func searchImages(for term: String, limit: Int) async throws -> [ClipartImageResult] {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: term),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: String(max(1, min(limit, 20)))),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|extmetadata"),
            URLQueryItem(name: "iiurlwidth", value: "512"),
            URLQueryItem(name: "format", value: "json")
        ]

        let response = try await decoded(WikimediaResponse.self, from: components.url!)
        let pages = response.query?.pages?.values.sorted { $0.pageid < $1.pageid } ?? []

        return pages.compactMap { page in
            guard let imageInfo = page.imageinfo?.first,
                  let imageURL = URL(string: imageInfo.url)
            else {
                return nil
            }

            return ClipartImageResult(
                id: "wikimedia-\(page.pageid)",
                title: page.title.removingWikimediaFilePrefix,
                imageURL: imageURL,
                thumbnailURL: imageInfo.thumburl.flatMap(URL.init(string:)),
                landingPageURL: imageInfo.descriptionurl.flatMap(URL.init(string:)),
                license: imageInfo.extmetadata?["LicenseShortName"]?.value.strippingHTML,
                creator: imageInfo.extmetadata?["Artist"]?.value.strippingHTML,
                sourceName: "Wikimedia Commons"
            )
        }
    }

    private func decoded<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response: response)
        return try JSONDecoder().decode(type, from: data)
    }
}

public enum ImageSearchError: Error {
    case badHTTPStatus(Int)
}

private func validate(response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else { return }
    guard (200..<300).contains(httpResponse.statusCode) else {
        throw ImageSearchError.badHTTPStatus(httpResponse.statusCode)
    }
}

private struct OpenverseResponse: Decodable {
    let results: [OpenverseImage]
}

private struct OpenverseImage: Decodable {
    let id: String
    let title: String?
    let url: String
    let thumbnail: String?
    let foreignLandingURL: String?
    let license: String?
    let creator: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case thumbnail
        case foreignLandingURL = "foreign_landing_url"
        case license
        case creator
        case source
    }
}

private struct WikimediaResponse: Decodable {
    let query: WikimediaQuery?
}

private struct WikimediaQuery: Decodable {
    let pages: [String: WikimediaPage]?
}

private struct WikimediaPage: Decodable {
    let pageid: Int
    let title: String
    let imageinfo: [WikimediaImageInfo]?
}

private struct WikimediaImageInfo: Decodable {
    let url: String
    let thumburl: String?
    let descriptionurl: String?
    let extmetadata: [String: WikimediaMetadata]?
}

private struct WikimediaMetadata: Decodable {
    let value: String
}

private extension String {
    var removingWikimediaFilePrefix: String {
        replacingOccurrences(of: "File:", with: "")
            .replacingOccurrences(of: "_", with: " ")
    }

    var strippingHTML: String {
        replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
