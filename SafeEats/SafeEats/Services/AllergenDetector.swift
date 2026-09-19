//
//  AllergenDetector.swift
//  SafeEats
//

import Foundation

/// Finds allergens in a block of recognised label text.
///
/// The detector is a pure value type: same text plus same profile always gives
/// the same result, with no camera, no storage and no main-actor involvement.
/// That is what makes the matching rules testable in isolation — see
/// `AllergenDetectorTests`.
struct AllergenDetector: Sendable {
    private let allergensByID: [AllergenID: Allergen]
    private let catalogOrder: [AllergenID]
    private let index: KeywordIndex
    private let advisory: AdvisoryMatcher

    init(catalog: AllergenCatalog, index: KeywordIndex, rules: DetectionRules) {
        self.allergensByID = Dictionary(
            catalog.allergens.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.catalogOrder = catalog.allergens.map(\.id)
        self.index = index
        self.advisory = AdvisoryMatcher(advisory: rules.advisory)
    }

    /// Scans `text` and returns the allergens named in it, in catalog order.
    ///
    /// - Parameters:
    ///   - text: Recognised label text, unnormalised.
    ///   - avoidedAllergens: The allergens the user has switched on. Detections
    ///     outside this set are still returned, marked `.informational`, so the
    ///     Scan tab can show everything it read and not just the bad news.
    func detect(in text: String, avoiding avoidedAllergens: Set<AllergenID>) -> [AllergenDetection] {
        let label = ScannedLabelText(text)
        guard !label.latinFolded.isEmpty else { return [] }

        var evidenceByAllergen: [AllergenID: [MatchEvidence]] = [:]

        for entry in index.entries {
            let haystack = label.haystack(for: entry.script)
            let ranges = haystack.matchRanges(of: entry.needle, boundary: entry.boundary)
            guard !ranges.isEmpty else { continue }

            // A term is only precautionary if *every* place it appears is. One
            // outright mention in the ingredient list outweighs any number of
            // "may contain" notices.
            let isPrecautionary = ranges.allSatisfy { range in
                advisory.isPrecautionary(
                    matchStart: range.lowerBound,
                    in: haystack,
                    script: entry.script
                )
            }

            evidenceByAllergen[entry.allergenID, default: []]
                .append(MatchEvidence(term: entry.term, isPrecautionary: isPrecautionary))
        }

        return catalogOrder.compactMap { id in
            guard let allergen = allergensByID[id],
                  let evidence = evidenceByAllergen[id] else { return nil }

            return AllergenDetection(
                allergen: allergen,
                severity: severity(for: id, evidence: evidence, avoiding: avoidedAllergens),
                evidence: Self.ranked(evidence)
            )
        }
    }

    /// Convenience wrapper that packages a scan's text and detections together.
    func result(for text: String, avoiding avoidedAllergens: Set<AllergenID>) -> ScanResult {
        ScanResult(
            recognizedText: text,
            detections: detect(in: text, avoiding: avoidedAllergens)
        )
    }

    private func severity(
        for id: AllergenID,
        evidence: [MatchEvidence],
        avoiding avoidedAllergens: Set<AllergenID>
    ) -> DetectionSeverity {
        guard avoidedAllergens.contains(id) else { return .informational }
        return evidence.allSatisfy(\.isPrecautionary) ? .advisory : .avoid
    }

    /// Orders evidence so the most informative term is first.
    ///
    /// Definite matches beat precautionary ones, then longer terms beat shorter
    /// ones — "peanut butter" says more about why something was flagged than
    /// "peanut" does.
    private static func ranked(_ evidence: [MatchEvidence]) -> [MatchEvidence] {
        evidence.sorted { lhs, rhs in
            if lhs.isPrecautionary != rhs.isPrecautionary {
                return !lhs.isPrecautionary
            }
            if lhs.term.text.count != rhs.term.text.count {
                return lhs.term.text.count > rhs.term.text.count
            }
            return lhs.term.text < rhs.term.text
        }
    }
}
