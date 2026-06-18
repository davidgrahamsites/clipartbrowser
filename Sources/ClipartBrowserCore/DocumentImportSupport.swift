import Foundation
import UniformTypeIdentifiers

public enum DocumentImportSupport {
    public static func isSupportedImportURL(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        guard !pathExtension.isEmpty else { return false }

        if supportedDocumentExtensions.contains(pathExtension) {
            return true
        }

        if isImagePathExtension(pathExtension) {
            return true
        }

        return UTType(filenameExtension: pathExtension)?.conforms(to: .plainText) == true
    }

    public static func isImagePathExtension(_ pathExtension: String) -> Bool {
        let normalized = pathExtension.lowercased()
        guard !normalized.isEmpty else { return false }

        return knownImageExtensions.contains(normalized)
            || UTType(filenameExtension: normalized)?.conforms(to: .image) == true
    }

    private static let supportedDocumentExtensions: Set<String> = [
        "docx",
        "pdf",
        "rtf",
        "rtfd",
        "txt"
    ]

    private static let knownImageExtensions: Set<String> = [
        "bmp",
        "gif",
        "heic",
        "heif",
        "jpeg",
        "jpg",
        "png",
        "tif",
        "tiff",
        "webp"
    ]
}
