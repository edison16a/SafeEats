//
//  DetectionRules.swift
//  SafeEats
//
//  Decoded form of `DetectionRules.json`.
//

import Foundation

/// Tunable rules for interpreting a match, kept out of the source so the
/// wording of precautionary statements can be corrected without a new build.
struct DetectionRules: Sendable, Decodable {
    struct Advisory: Sendable, Decodable {
        struct Phrase: Sendable, Decodable {
            let language: String
            let text: String
        }

        /// How far back from a match to look for a precautionary phrase.
        let lookbehindCharacterLimit: Int
        /// Characters that end a statement; a phrase on the far side of one
        /// does not apply to the match.
        let sentenceTerminators: [String]
        let phrases: [Phrase]
    }

    let schemaVersion: Int
    let advisory: Advisory
}

/// Decides whether a keyword match sits inside a "may contain" statement.
///
/// The old implementation tested `text.contains("may contain \(keyword)")`,
/// which only fired when the allergen word came *immediately* after the phrase.
/// Real labels read "May contain traces of peanuts, tree nuts and sesame", so
/// every term but the first was reported as a definite ingredient.
///
/// This looks backwards from the match instead, and stops at a sentence
/// terminator so that:
///
/// ```
/// May contain: peanuts
/// Contains: milk
/// ```
///
/// does not let the first line's "May contain" soften the milk on the second.
struct AdvisoryMatcher: Sendable {
    private let lookbehindLimit: Int
    private let terminators: Set<Character>
    private let latinPhrases: [String]
    private let unicodePhrases: [String]

    init(advisory: DetectionRules.Advisory) {
        self.lookbehindLimit = max(0, advisory.lookbehindCharacterLimit)
        self.terminators = Set(advisory.sentenceTerminators.compactMap(\.first))
        // Phrases are folded the same two ways as the label text so they can be
        // compared against whichever haystack the matched term used.
        self.latinPhrases = advisory.phrases.map {
            ScannedLabelText.foldedTerm($0.text, script: .segmented)
        }
        self.unicodePhrases = advisory.phrases.map {
            ScannedLabelText.foldedTerm($0.text, script: .unsegmented)
        }
    }

    /// Whether the match starting at `matchStart` is governed by a precautionary phrase.
    ///
    /// - Parameters:
    ///   - matchStart: Lower bound of the match, an index into `haystack`.
    ///   - haystack: The folded text the match was found in.
    ///   - script: Which folding `haystack` used, so the right phrase list is searched.
    func isPrecautionary(
        matchStart: String.Index,
        in haystack: String,
        script: TermScript
    ) -> Bool {
        guard matchStart > haystack.startIndex else { return false }

        let windowStart = haystack.index(
            matchStart,
            offsetBy: -lookbehindLimit,
            limitedBy: haystack.startIndex
        ) ?? haystack.startIndex

        let window = haystack[windowStart..<matchStart]
        guard !window.isEmpty else { return false }

        let phrases = script == .segmented ? latinPhrases : unicodePhrases

        for phrase in phrases where !phrase.isEmpty {
            // `.backwards` finds the phrase nearest the match, which is the one
            // that governs it.
            guard let range = window.range(of: phrase, options: [.literal, .backwards]) else {
                continue
            }
            let between = window[range.upperBound...]
            if between.contains(where: terminators.contains) {
                continue
            }
            return true
        }

        return false
    }
}
