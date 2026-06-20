import Foundation
import ZIPFoundation

/// Builds a numbered list of slide labels (e.g. "1 - Tall") as plain text or a
/// minimal Word `.docx` document.
public enum WordListExporter {
    /// The numbered list as plain text, one entry per line: `"1 - Tall"`.
    public static func text(for words: [String]) -> String {
        lines(for: words).joined(separator: "\n")
    }

    /// The numbered list as a minimal, Word-compatible `.docx` (OOXML) file,
    /// one paragraph per entry.
    public static func makeDOCX(for words: [String]) throws -> Data {
        let archive = try Archive(accessMode: .create)
        try addFile(Data(contentTypesXML.utf8), path: "[Content_Types].xml", to: archive)
        try addFile(Data(packageRelationshipsXML.utf8), path: "_rels/.rels", to: archive)
        try addFile(Data(documentXML(for: words).utf8), path: "word/document.xml", to: archive)

        guard let data = archive.data else {
            throw WordListExportError.archiveCreationFailed
        }
        return data
    }

    static func lines(for words: [String]) -> [String] {
        words.enumerated().map { index, word in
            "\(index + 1) - \(label(for: word))"
        }
    }

    /// Title-cases the stored vocabulary word for display (e.g. "bridge
    /// building" -> "Bridge Building", matching the requested "Tall"/"Short").
    static func label(for word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }
}

private enum WordListExportError: Error {
    case archiveCreationFailed
}

private extension WordListExporter {
    static func addFile(_ data: Data, path: String, to archive: Archive) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, size in
            let start = Int(position)
            guard start < data.count else { return Data() }
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }

    static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """

    static let packageRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """

    static func documentXML(for words: [String]) -> String {
        let paragraphs = lines(for: words).map { line in
            """
              <w:p><w:r><w:t xml:space="preserve">\(escapeXML(line))</w:t></w:r></w:p>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
        \(paragraphs)
            <w:sectPr/>
          </w:body>
        </w:document>
        """
    }

    static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
