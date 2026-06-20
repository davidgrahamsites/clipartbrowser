import Foundation

/// Which web image-search engine the in-app browser uses. Picking mechanics
/// (full-size image extraction, bigger-of-two download, trimming, upscaling) are
/// engine-agnostic and work the same for every case.
public enum ImageSearchEngine: String, CaseIterable, Identifiable, Sendable {
    case google
    case baidu

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .google: return "Google"
        case .baidu: return "Baidu"
        }
    }

    public func searchURL(for term: String) -> URL {
        switch self {
        case .google:
            return GoogleImagesSearch.url(for: term)
        case .baidu:
            return BaiduImagesSearch.url(for: term)
        }
    }
}

public enum BaiduImagesSearch {
    public static func url(for term: String) -> URL {
        var components = URLComponents(string: "https://image.baidu.com/search/index")!
        components.queryItems = [
            URLQueryItem(name: "tn", value: "baiduimage"),
            URLQueryItem(name: "ie", value: "utf-8"),
            URLQueryItem(name: "word", value: "\(term) clipart")
        ]
        return components.url!
    }
}
