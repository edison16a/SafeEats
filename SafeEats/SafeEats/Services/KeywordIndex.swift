//
//  KeywordIndex.swift
//  SafeEats
//

import Foundation

/// Every allergen keyword, pre-folded and ready to match against label text.
///
/// Building this once at launch keeps the per-scan cost to the string searches
/// themselves: no case folding, diacritic stripping or script classification
/// happens while the user is waiting.
struct KeywordIndex: Sendable {
    /// One searchable keyword belonging to one allergen.
    struct Entry: Sendable {
        let allergenID: AllergenID
        /// The original term, carried through so a match can be explained.
        let term: KeywordTerm
        /// ``term`` folded to match the haystack chosen by ``script``.
        let needle: String
        let script: TermScript
        let boundary: MatchBoundary
    }

    let entries: [Entry]

    /// Number of searchable keywords, useful in diagnostics and tests.
    var count: Int { entries.count }

    /// Builds the index from the decoded keyword resources.
    ///
    /// Terms are de-duplicated per allergen by their folded form, because the
    /// source vocabularies legitimately repeat a word across languages ("Ei" is
    /// both Dutch and German) and searching for it twice would only cost time.
    /// The same word belonging to *different* allergens is kept, because
    /// "wheat" really does flag both wheat and gluten.
    init(keywordSets: [AllergenKeywordSet]) {
        var entries: [Entry] = []
        entries.reserveCapacity(keywordSets.reduce(0) { $0 + $1.allTerms.count })

        for set in keywordSets {
            var seen = Set<String>()

            for term in set.allTerms {
                let script = TermScript.classify(term.text)
                let needle = ScannedLabelText.foldedTerm(term.text, script: script)

                guard !needle.isEmpty, seen.insert(needle).inserted else { continue }

                entries.append(
                    Entry(
                        allergenID: set.allergenID,
                        term: term,
                        needle: needle,
                        script: script,
                        boundary: Self.boundary(for: term, script: script)
                    )
                )
            }
        }

        self.entries = entries
    }

    /// Chooses how strictly a term must be delimited in the label text.
    private static func boundary(for term: KeywordTerm, script: TermScript) -> MatchBoundary {
        switch script {
        case .unsegmented:
            // Chinese and Japanese are written without spaces.
            return .none
        case .segmented:
            // "E322" must not match inside "E3220"; "corn" should still match
            // inside "cornstarch".
            return term.kind == .additiveCode ? .leadingAndTrailing : .leading
        }
    }
}
