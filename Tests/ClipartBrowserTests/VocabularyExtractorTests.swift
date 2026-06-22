import XCTest
@testable import ClipartBrowserCore

final class VocabularyExtractorTests: XCTestCase {
    func testDetectsVocabularySectionAndIgnoresRegularBodyText() {
        let text = """
        Lesson 4: Living Things

        Key Words
        1. habitat - a place where an animal lives
        2. migration: movement from one place to another
        3. life cycle

        Reading
        The migration of birds can be affected by habitat loss.
        """

        let terms = VocabularyExtractor.extractCandidates(from: text).map(\.term)

        XCTAssertEqual(terms, ["habitat", "migration", "life cycle"])
    }

    func testDetectsInlineVocabularyHeadingListInOrder() {
        let text = """
        Science notes
        Vocabulary Words: photosynthesis, chlorophyll, carbon dioxide
        Write each word in a sentence.
        """

        let terms = VocabularyExtractor.extractCandidates(from: text).map(\.term)

        XCTAssertEqual(terms, ["photosynthesis", "chlorophyll", "carbon dioxide"])
    }

    func testDetectsLessonPlanKeyWordsAndStopsAtKeySentences() {
        let text = """
        Theme 2: Hot Summer

        Key Words
        summer, hot, sun, fan, hat, ice cream, water

        Key Sentences
        1. What's the season? It's summer.
        """

        let terms = VocabularyExtractor.extractCandidates(from: text).map(\.term)

        XCTAssertEqual(terms, ["summer", "hot", "sun", "fan", "hat", "ice cream", "water"])
    }

    func testDetectsTitleLikeVocabularyHeadingWithQualifier() {
        let text = """
        Unit 5 Vocabulary
        tall
        short
        happy

        Comprehension
        Answer the questions below.
        """

        let terms = VocabularyExtractor.extractCandidates(from: text).map(\.term)

        XCTAssertEqual(terms, ["tall", "short", "happy"])
    }

    func testDetectsTitleLikeSpellingWordsHeading() {
        let text = """
        Week 3 Spelling Words
        because
        friend
        people
        """

        let terms = VocabularyExtractor.extractCandidates(from: text).map(\.term)

        XCTAssertEqual(terms, ["because", "friend", "people"])
    }

    func testDoesNotTreatOrdinarySentenceEndingInVocabularyAsHeading() {
        let text = """
        Students will learn new vocabulary
        The lesson covers several topics.
        """

        let terms = VocabularyExtractor.extractCandidates(from: text).map(\.term)

        XCTAssertEqual(terms, [])
    }

    func testDetectsOCRLineWithKeyWordsPrefixAndCommaList() {
        let text = """
        Key Words summer, hot, sun, fan, hat, ice cream, water
        Key Sentences
        """

        let terms = VocabularyExtractor.extractCandidates(from: text).map(\.term)

        XCTAssertEqual(terms, ["summer", "hot", "sun", "fan", "hat", "ice cream", "water"])
    }
}
