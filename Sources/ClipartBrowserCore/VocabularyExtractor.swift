import Foundation

public struct VocabularyCandidate: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let term: String
    public let sourceLine: Int

    public init(id: UUID = UUID(), term: String, sourceLine: Int) {
        self.id = id
        self.term = term
        self.sourceLine = sourceLine
    }
}

public enum VocabularyExtractor {
    public static func extractCandidates(from text: String) -> [VocabularyCandidate] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)

        var candidates: [VocabularyCandidate] = []
        var inVocabularySection = false
        var seenTerms = Set<String>()

        for (offset, rawLine) in lines.enumerated() {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let inlineTerms = inlineTerms(from: line) {
                append(inlineTerms, sourceLine: offset + 1, to: &candidates, seenTerms: &seenTerms)
                inVocabularySection = false
                continue
            }

            if let inlineTerms = headingPrefixedTerms(from: line) {
                append(inlineTerms, sourceLine: offset + 1, to: &candidates, seenTerms: &seenTerms)
                inVocabularySection = false
                continue
            }

            if isVocabularyHeading(line) {
                inVocabularySection = true
                continue
            }

            guard inVocabularySection else { continue }

            if isLikelySectionHeading(line) {
                inVocabularySection = false
                continue
            }

            let terms = terms(fromVocabularyLine: line)
            append(terms, sourceLine: offset + 1, to: &candidates, seenTerms: &seenTerms)
        }

        return candidates
    }
}

private extension VocabularyExtractor {
    static let headingWords: Set<String> = [
        "key terms",
        "key vocabulary",
        "key words",
        "keywords",
        "terms to know",
        "vocab",
        "vocabulary",
        "vocabulary list",
        "vocabulary terms",
        "vocabulary words",
        "word bank",
        "words to know"
    ]

    static let stopHeadings: Set<String> = [
        "activity",
        "answer key",
        "comprehension",
        "discussion",
        "exercise",
        "homework",
        "key sentences",
        "lesson",
        "learning objectives",
        "practice",
        "questions",
        "reading",
        "review",
        "weekly activity suggestions",
        "worksheet",
        "writing"
    ]

    static func append(
        _ terms: [String],
        sourceLine: Int,
        to candidates: inout [VocabularyCandidate],
        seenTerms: inout Set<String>
    ) {
        for term in terms {
            let key = term.lowercased()
            guard !seenTerms.contains(key) else { continue }
            seenTerms.insert(key)
            candidates.append(VocabularyCandidate(term: term, sourceLine: sourceLine))
        }
    }

    static func inlineTerms(from line: String) -> [String]? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }

        let prefix = String(line[..<colonIndex])
        guard isVocabularyHeading(prefix) else { return nil }

        let suffix = String(line[line.index(after: colonIndex)...])
        let terms = splitTermList(suffix)
        return terms.isEmpty ? nil : terms
    }

    static func headingPrefixedTerms(from line: String) -> [String]? {
        let normalizedLine = normalizedHeading(line)
        for heading in headingWords.sorted(by: { $0.count > $1.count }) {
            guard normalizedLine.hasPrefix("\(heading) ") else { continue }

            let suffixStart = line.index(line.startIndex, offsetBy: min(heading.count, line.count))
            let suffix = String(line[suffixStart...])
            let terms = splitTermList(suffix)
            return terms.isEmpty ? nil : terms
        }
        return nil
    }

    static func terms(fromVocabularyLine line: String) -> [String] {
        if line.contains(",") || line.contains(";") {
            return splitTermList(line)
        }

        let term = cleanTerm(line)
        guard !term.isEmpty else { return [] }
        guard isPlausibleTerm(term) else { return [] }
        return [term]
    }

    static func splitTermList(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { cleanTerm(String($0)) }
            .filter { !$0.isEmpty && isPlausibleTerm($0) }
    }

    static func cleanTerm(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = removeLeadingListMarker(from: value)

        for separator in [" - ", " -- ", ":", "\t"] {
            if let range = value.range(of: separator) {
                value = String(value[..<range.lowerBound])
            }
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: ".:;-"))
        value = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return value
    }

    static func removeLeadingListMarker(from value: String) -> String {
        value.replacingOccurrences(
            of: #"^\s*(?:\d+[\.)]|[A-Za-z][\.)]|[-*•])\s+"#,
            with: "",
            options: .regularExpression
        )
    }

    static func isVocabularyHeading(_ line: String) -> Bool {
        let normalized = normalizedHeading(line)
        return headingWords.contains(normalized)
    }

    static func isLikelySectionHeading(_ line: String) -> Bool {
        let normalized = normalizedHeading(line)
        if stopHeadings.contains(normalized) { return true }
        if headingWords.contains(normalized) { return true }
        return false
    }

    static func normalizedHeading(_ line: String) -> String {
        line.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func isPlausibleTerm(_ term: String) -> Bool {
        let wordCount = term.split(whereSeparator: \.isWhitespace).count
        guard (1...5).contains(wordCount) else { return false }

        let lowercased = term.lowercased()
        let instructionPrefixes = ["read ", "write ", "use ", "answer ", "define ", "draw "]
        guard !instructionPrefixes.contains(where: { lowercased.hasPrefix($0) }) else { return false }

        return !term.contains(".") && !term.contains("?") && !term.contains("!")
    }
}
