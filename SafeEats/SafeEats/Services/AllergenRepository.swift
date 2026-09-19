//
//  AllergenRepository.swift
//  SafeEats
//

import Foundation
import OSLog

/// Loads the allergen catalog and its keyword vocabularies, and hands back a
/// detector built from them.
///
/// This is the single place that knows the allergen data is stored as JSON. The
/// UI and the detector deal only in model types, so moving the vocabulary to a
/// downloadable bundle later would not reach past this file.
struct AllergenRepository: Sendable {
    let catalog: AllergenCatalog
    let keywordIndex: KeywordIndex
    let rules: DetectionRules
    let detector: AllergenDetector

    private static let catalogResourceName = "AllergenCatalog"
    private static let rulesResourceName = "DetectionRules"

    /// Loads every allergen resource from the bundle.
    ///
    /// - Throws: ``BundleResourceLoader/LoaderError`` if the catalog, the rules
    ///   or any keyword file named by the catalog is missing or malformed.
    ///   Missing data is treated as fatal rather than recovered from: an
    ///   allergen scanner silently missing a vocabulary is worse than one that
    ///   refuses to start.
    init(loader: BundleResourceLoader = .main) throws {
        let catalog = try loader.load(AllergenCatalog.self, named: Self.catalogResourceName)
        let rules = try loader.load(DetectionRules.self, named: Self.rulesResourceName)

        let keywordSets = try catalog.allergens.map { allergen in
            try loader.load(AllergenKeywordSet.self, named: allergen.keywordResourceName)
        }

        // A mismatch means the catalog and the keyword file disagree about which
        // allergen they describe. Detection still works — the catalog wins — but
        // it almost certainly signals a copy-paste error in the resources.
        for (allergen, set) in zip(catalog.allergens, keywordSets) where set.allergenID != allergen.id {
            Log.resources.warning(
                "Keyword file for '\(allergen.id.rawValue, privacy: .public)' declares '\(set.allergenID.rawValue, privacy: .public)'."
            )
        }

        let index = KeywordIndex(keywordSets: keywordSets)

        self.catalog = catalog
        self.rules = rules
        self.keywordIndex = index
        self.detector = AllergenDetector(catalog: catalog, index: index, rules: rules)

        Log.resources.info(
            "Loaded \(catalog.allergens.count) allergens and \(index.count) keywords."
        )
    }
}
