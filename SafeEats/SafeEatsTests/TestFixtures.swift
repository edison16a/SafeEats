//
//  TestFixtures.swift
//  SafeEatsTests
//
//  Small hand-built catalogs, so the matching rules can be tested without
//  depending on the 1,500-term shipping vocabulary.
//

import Foundation
@testable import SafeEats

enum Fixtures {
    /// Advisory rules mirroring the shipped `DetectionRules.json`, trimmed to
    /// the phrases the tests exercise.
    static func rules(
        lookbehind: Int = 80,
        phrases: [String] = ["may contain", "traces of", "produced in a facility", "可能含有"]
    ) -> DetectionRules {
        DetectionRules(
            schemaVersion: 1,
            advisory: DetectionRules.Advisory(
                lookbehindCharacterLimit: lookbehind,
                sentenceTerminators: [".", ";", "!", "?", "\n"],
                phrases: phrases.map { DetectionRules.Advisory.Phrase(language: "en", text: $0) }
            )
        )
    }

    static func category(_ id: String = "common") -> AllergenCategory {
        AllergenCategory(id: id, title: "Common", subtitle: "Test category")
    }

    static func allergen(_ id: String, name: String? = nil) -> Allergen {
        Allergen(
            id: AllergenID(id),
            name: name ?? id.capitalized,
            categoryID: "common",
            iconAssetName: id,
            keywordResourceName: "AllergenKeywords-\(id)"
        )
    }

    static func keywordSet(_ id: String, terms: [KeywordTerm]) -> AllergenKeywordSet {
        AllergenKeywordSet(
            schemaVersion: 1,
            allergenID: AllergenID(id),
            groups: [AllergenKeywordSet.Group(language: "en", terms: terms)]
        )
    }

    /// Builds a detector over an inline vocabulary.
    ///
    /// - Parameter vocabulary: allergen id paired with the terms that identify it.
    static func detector(
        vocabulary: [(id: String, terms: [KeywordTerm])],
        rules: DetectionRules = Fixtures.rules()
    ) -> AllergenDetector {
        let catalog = AllergenCatalog(
            schemaVersion: 1,
            categories: [category()],
            allergens: vocabulary.map { allergen($0.id) }
        )
        let index = KeywordIndex(
            keywordSets: vocabulary.map { keywordSet($0.id, terms: $0.terms) }
        )
        return AllergenDetector(catalog: catalog, index: index, rules: rules)
    }

    /// A detector with one allergen per supplied plain-text term list.
    static func detector(
        plainVocabulary: [String: [String]],
        rules: DetectionRules = Fixtures.rules()
    ) -> AllergenDetector {
        detector(
            vocabulary: plainVocabulary
                .sorted { $0.key < $1.key }
                .map { (id: $0.key, terms: $0.value.map { KeywordTerm(text: $0) }) },
            rules: rules
        )
    }

    /// Scratch defaults that never touch the real app domain.
    static func isolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "SafeEatsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create an isolated UserDefaults suite")
        }
        return (defaults, suiteName)
    }
}
