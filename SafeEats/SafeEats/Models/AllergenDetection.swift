//
//  AllergenDetection.swift
//  SafeEats
//

import Foundation

/// How seriously the user should take a detected allergen.
///
/// Declaration order is the severity order, which the synthesised `Comparable`
/// conformance relies on.
enum DetectionSeverity: Hashable, Sendable, Comparable {
    /// Found on the label, but not one of the user's allergens.
    case informational
    /// One of the user's allergens, named only in a precautionary statement
    /// such as "may contain traces of".
    case advisory
    /// One of the user's allergens, named outright in the ingredients.
    case avoid
}

/// The specific keyword that caused an allergen to be flagged.
///
/// Carrying the evidence through to the UI is what makes a match explainable:
/// a chip reading "Soy — E322" tells the user far more than "Soy" alone, and
/// lets them judge a broad match for themselves.
struct MatchEvidence: Hashable, Sendable {
    let term: KeywordTerm
    /// True when *every* occurrence of this term sat behind a precautionary phrase.
    let isPrecautionary: Bool
}

/// One allergen found in a scan, with the evidence for it.
struct AllergenDetection: Identifiable, Hashable, Sendable {
    let allergen: Allergen
    let severity: DetectionSeverity
    /// Matching keywords, most specific (longest) first.
    let evidence: [MatchEvidence]

    var id: AllergenID { allergen.id }

    /// The single most informative term to show on a compact chip.
    var headlineTerm: KeywordTerm? { evidence.first?.term }

    /// True when the allergen was named only in precautionary statements.
    var isPrecautionaryOnly: Bool {
        !evidence.isEmpty && evidence.allSatisfy(\.isPrecautionary)
    }
}

/// The outcome of a single scan.
struct ScanResult: Sendable {
    /// Text as returned by the recogniser, kept so the user can see what was read.
    let recognizedText: String
    /// Detected allergens in catalog order.
    let detections: [AllergenDetection]

    /// Detections the user needs to act on, worst first.
    var actionable: [AllergenDetection] {
        detections
            .filter { $0.severity > .informational }
            .sorted { $0.severity > $1.severity }
    }

    /// True when the recogniser found no usable text at all.
    var isEmpty: Bool {
        recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let none = ScanResult(recognizedText: "", detections: [])
}
