//
//  AllergenDetectorTests.swift
//  SafeEatsTests
//

import Foundation
import Testing
@testable import SafeEats

@Suite("Allergen detection")
struct AllergenDetectorTests {

    private let peanut = AllergenID("peanut")
    private let dairy = AllergenID("dairy")
    private let sesame = AllergenID("sesame")

    private func standardDetector() -> AllergenDetector {
        Fixtures.detector(plainVocabulary: [
            "peanut": ["peanut", "peanut butter", "groundnut", "Erdnussöl", "花生"],
            "dairy": ["milk", "whey", "Leche entera", "牛奶"],
            "sesame": ["sesame", "tahini"]
        ])
    }

    // MARK: - Basic matching

    @Test("A named ingredient is flagged for an allergen the user avoids")
    func definiteMatch() {
        let detections = standardDetector().detect(
            in: "Ingredients: sugar, roasted peanuts, salt.",
            avoiding: [peanut]
        )

        #expect(detections.count == 1)
        #expect(detections.first?.allergen.id == peanut)
        #expect(detections.first?.severity == .avoid)
    }

    @Test("An allergen the user has not selected is reported as informational")
    func unselectedAllergenIsInformational() {
        let detections = standardDetector().detect(
            in: "Ingredients: sugar, roasted peanuts, salt.",
            avoiding: []
        )

        #expect(detections.first?.severity == .informational)
    }

    @Test("Text with no known keywords yields nothing")
    func noMatches() {
        let detections = standardDetector().detect(
            in: "Ingredients: water, sugar, citric acid.",
            avoiding: [peanut, dairy]
        )

        #expect(detections.isEmpty)
    }

    @Test("Empty text yields nothing")
    func emptyText() {
        #expect(standardDetector().detect(in: "", avoiding: [peanut]).isEmpty)
        #expect(standardDetector().detect(in: "   \n  ", avoiding: [peanut]).isEmpty)
    }

    // MARK: - Case and diacritics

    @Test("Capitalised and accented keywords match, which they never used to")
    func foldingMakesNonEnglishTermsReachable() {
        // The old matcher lower-cased the label but compared it against the raw
        // keyword, so every capitalised entry — the whole German, Dutch and
        // Spanish vocabulary — was dead weight.
        let detector = standardDetector()

        #expect(detector.detect(in: "Zutaten: Erdnussöl", avoiding: [peanut]).count == 1)
        #expect(detector.detect(in: "ERDNUSSOL", avoiding: [peanut]).count == 1)
        #expect(detector.detect(in: "Ingredientes: leche entera", avoiding: [dairy]).count == 1)
    }

    @Test("Chinese keywords match without word boundaries")
    func unsegmentedScriptMatching() {
        let detections = standardDetector().detect(in: "配料:水、牛奶、砂糖", avoiding: [dairy])

        #expect(detections.count == 1)
        #expect(detections.first?.allergen.id == dairy)
    }

    // MARK: - Precautionary statements

    @Test("Every allergen in a 'may contain' list is treated as precautionary")
    func advisoryListMarksEveryTerm() {
        // The old check was `text.contains("may contain \(keyword)")`, so only
        // the allergen immediately after the phrase was softened; everything
        // later in the sentence was reported as a definite ingredient.
        let detections = standardDetector().detect(
            in: "May contain traces of peanuts, sesame and milk.",
            avoiding: [peanut, sesame, dairy]
        )

        #expect(detections.count == 3)
        #expect(detections.allSatisfy { $0.severity == .advisory })
    }

    @Test("A definite mention outweighs a precautionary one")
    func definiteBeatsAdvisory() {
        let detections = standardDetector().detect(
            in: "Contains peanut. May contain traces of peanut.",
            avoiding: [peanut]
        )

        #expect(detections.count == 1)
        #expect(detections.first?.severity == .avoid)
    }

    @Test("A precautionary phrase does not leak across a line break")
    func advisoryStopsAtLineBreak() {
        let detections = standardDetector().detect(
            in: "May contain: peanuts\nContains: milk",
            avoiding: [peanut, dairy]
        )

        let bySeverity = Dictionary(
            uniqueKeysWithValues: detections.map { ($0.allergen.id, $0.severity) }
        )

        #expect(bySeverity[peanut] == .advisory)
        #expect(bySeverity[dairy] == .avoid)
    }

    @Test("A precautionary phrase does not leak across a full stop")
    func advisoryStopsAtSentenceEnd() {
        let detections = standardDetector().detect(
            in: "Produced in a facility that handles sesame. Contains milk.",
            avoiding: [sesame, dairy]
        )

        let bySeverity = Dictionary(
            uniqueKeysWithValues: detections.map { ($0.allergen.id, $0.severity) }
        )

        #expect(bySeverity[sesame] == .advisory)
        #expect(bySeverity[dairy] == .avoid)
    }

    @Test("A phrase beyond the lookbehind window does not apply")
    func advisoryWindowIsBounded() {
        let detector = Fixtures.detector(
            plainVocabulary: ["peanut": ["peanut"]],
            rules: Fixtures.rules(lookbehind: 10)
        )
        let padding = String(repeating: "x", count: 40)
        let detections = detector.detect(in: "may contain \(padding) peanut", avoiding: [peanut])

        #expect(detections.first?.severity == .avoid)
    }

    // MARK: - Evidence

    @Test("The longest definite term is offered as the headline evidence")
    func evidenceIsRanked() {
        let detections = standardDetector().detect(
            in: "Ingredients: peanut butter, sugar.",
            avoiding: [peanut]
        )

        #expect(detections.first?.headlineTerm?.text == "peanut butter")
        // Both "peanut" and "peanut butter" matched.
        #expect((detections.first?.evidence.count ?? 0) >= 2)
    }

    @Test("Results come back in catalog order")
    func resultsFollowCatalogOrder() {
        let detector = Fixtures.detector(vocabulary: [
            (id: "alpha", terms: [KeywordTerm(text: "milk")]),
            (id: "beta", terms: [KeywordTerm(text: "soy")])
        ])
        let detections = detector.detect(in: "soy lecithin and milk", avoiding: [])

        #expect(detections.map(\.allergen.id.rawValue) == ["alpha", "beta"])
    }

    @Test("Additive codes are matched only when fully delimited")
    func additiveCodeBoundaries() {
        let detector = Fixtures.detector(vocabulary: [
            (id: "soy", terms: [KeywordTerm(text: "E322", kind: .additiveCode, note: "soy lecithin")])
        ])
        let soy = AllergenID("soy")

        #expect(detector.detect(in: "emulsifier (E322)", avoiding: [soy]).count == 1)
        #expect(detector.detect(in: "colouring E3221", avoiding: [soy]).isEmpty)
    }

    // MARK: - ScanResult

    @Test("ScanResult surfaces the actionable detections worst-first")
    func actionableOrdering() {
        let result = standardDetector().result(
            for: "Contains milk. May contain traces of peanuts.",
            avoiding: [peanut, dairy]
        )

        #expect(result.actionable.map(\.severity) == [.avoid, .advisory])
        #expect(!result.isEmpty)
    }
}
