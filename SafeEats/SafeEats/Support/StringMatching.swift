//
//  StringMatching.swift
//  SafeEats
//
//  Boundary-aware substring search used by the allergen detector.
//

import Foundation

/// How much of a word boundary a keyword needs around it to count as a match.
enum MatchBoundary: Sendable, Hashable {
    /// Match anywhere, used for scripts written without word separators.
    case none
    /// The character before the match must not be alphanumeric.
    ///
    /// This is the default for Latin-script keywords. It keeps useful partial
    /// matches (`"corn"` inside `"cornstarch"`) while rejecting the accidental
    /// ones the old `contains` check produced, such as `"ham"` inside
    /// `"graham"` or `"oat"` inside `"coating"`.
    case leading
    /// Both surrounding characters must be non-alphanumeric.
    ///
    /// Used for additive codes, where `"E322"` should not fire on `"E3220"`.
    case leadingAndTrailing
}

extension String {
    /// Returns every range in which `needle` occurs subject to `boundary`.
    ///
    /// Both the receiver and `needle` are expected to have been folded by
    /// ``ScannedLabelText`` already, so the search runs with `.literal`. That
    /// skips per-comparison case and canonical-equivalence work.
    ///
    /// - Complexity: O(*n* × *m*) worst case for a haystack of length *n* and a
    ///   needle of length *m*. Label text is short and scans are user-driven,
    ///   so the flat scan is preferred over the cost of maintaining an index.
    func matchRanges(of needle: String, boundary: MatchBoundary) -> [Range<String.Index>] {
        guard !needle.isEmpty, !isEmpty else { return [] }

        var results: [Range<String.Index>] = []
        var searchStart = startIndex

        while searchStart < endIndex,
              let range = range(of: needle, options: .literal, range: searchStart..<endIndex) {
            if satisfiesBoundary(boundary, for: range) {
                results.append(range)
            }
            // Step one character past the start of this hit rather than past its
            // end, so overlapping occurrences are not skipped.
            searchStart = index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }

        return results
    }

    /// Whether `needle` occurs at least once subject to `boundary`.
    func containsMatch(of needle: String, boundary: MatchBoundary) -> Bool {
        !matchRanges(of: needle, boundary: boundary).isEmpty
    }

    private func satisfiesBoundary(_ boundary: MatchBoundary, for range: Range<String.Index>) -> Bool {
        switch boundary {
        case .none:
            return true
        case .leading:
            return hasBoundary(before: range.lowerBound)
        case .leadingAndTrailing:
            return hasBoundary(before: range.lowerBound) && hasBoundary(at: range.upperBound)
        }
    }

    /// True when the character preceding `position` cannot be part of a word.
    private func hasBoundary(before position: String.Index) -> Bool {
        guard position > startIndex else { return true }
        return !isWordCharacter(self[index(before: position)])
    }

    /// True when the character at `position` cannot be part of a word.
    private func hasBoundary(at position: String.Index) -> Bool {
        guard position < endIndex else { return true }
        return !isWordCharacter(self[position])
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
