import Foundation

public enum GoogleImagesSearch {
    public static func url(for term: String) -> URL {
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [
            URLQueryItem(name: "tbm", value: "isch"),
            URLQueryItem(name: "q", value: "\(term) clipart")
        ]
        return components.url!
    }
}
