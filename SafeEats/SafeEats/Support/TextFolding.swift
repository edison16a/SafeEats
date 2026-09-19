//
//  TextFolding.swift
//  SafeEats
//
//  Normalisation used on both sides of allergen matching.
//

import Foundation

/// How a written script separates words, which decides how a keyword may be matched.
///
/// Latin-script terms are matched on word boundaries so that `"ham"` does not
/// fire inside `"graham"`. Chinese and Japanese are written without spaces, so
/// their terms have to be matched as plain substrings.
enum TermScript: Sendable, Hashable {
    /// A script that separates words with spaces or punctuation (Latin, Cyrillic, …).
    case segmented
    /// A script written without word separators (Han, Kana, Hangul).
    case unsegmented

    /// Classifies a term by looking for characters from unsegmented scripts.
    static func classify(_ text: String) -> TermScript {
        for scalar in text.unicodeScalars where isUnsegmented(scalar) {
            return .unsegmented
        }
        return .segmented
    }

    private static func isUnsegmented(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF,  // Hiragana + Katakana
             0x3400...0x4DBF,  // CJK Unified Ideographs Extension A
             0x4E00...0x9FFF,  // CJK Unified Ideographs
             0xAC00...0xD7AF,  // Hangul Syllables
             0xF900...0xFAFF,  // CJK Compatibility Ideographs
             0xFF65...0xFF9F:  // Halfwidth Katakana
            return true
        default:
            return false
        }
    }
}

/// A block of text prepared for allergen matching.
///
/// Two foldings are kept because one size does not fit all scripts:
///
/// - ``latinFolded`` strips diacritics, so a label reading `"Maíz"` matches the
///   keyword `"maiz"`.
/// - ``unicodeFolded`` leaves combining marks alone, because stripping them
///   from Japanese would turn `"バター"` (butter) into `"ハター"` (nothing).
///
/// Both foldings lower-case and normalise character width, and both collapse
/// runs of spaces and tabs. Line breaks are deliberately preserved: they mark
/// the boundary between, say, a `Contains:` line and a `May contain:` line, and
/// ``AdvisoryMatcher`` relies on them to avoid mislabelling a definite
/// ingredient as a precautionary one.
struct ScannedLabelText: Sendable {
    /// The text exactly as the recogniser produced it.
    let raw: String
    /// Case-, width- and diacritic-folded text, used for segmented scripts.
    let latinFolded: String
    /// Case- and width-folded text, used for unsegmented scripts.
    let unicodeFolded: String

    init(_ raw: String) {
        self.raw = raw
        let collapsed = Self.collapsingHorizontalWhitespace(in: raw)
        self.unicodeFolded = Self.fold(collapsed, stripDiacritics: false)
        self.latinFolded = Self.fold(collapsed, stripDiacritics: true)
    }

    /// Returns the folded text a term of the given script should be matched against.
    func haystack(for script: TermScript) -> String {
        switch script {
        case .segmented: return latinFolded
        case .unsegmented: return unicodeFolded
        }
    }

    /// Folds a keyword so that it can be compared against the matching haystack.
    ///
    /// Terms are stored in the JSON resources in their natural, human-readable
    /// form (`"Leche entera"`); this is what turns them into a comparable key.
    static func foldedTerm(_ term: String, script: TermScript) -> String {
        let collapsed = collapsingHorizontalWhitespace(in: term)
        return fold(collapsed, stripDiacritics: script == .segmented)
    }

    private static func fold(_ text: String, stripDiacritics: Bool) -> String {
        var options: String.CompareOptions = [.caseInsensitive, .widthInsensitive]
        if stripDiacritics {
            options.insert(.diacriticInsensitive)
        }
        return text
            .precomposedStringWithCanonicalMapping
            .folding(options: options, locale: nil)
    }

    /// Collapses runs of spaces, tabs and non-breaking spaces, keeping newlines.
    private static func collapsingHorizontalWhitespace(in text: String) -> String {
        text.replacingOccurrences(
            of: "[ \t\u{00A0}\u{3000}]+",
            with: " ",
            options: .regularExpression
        )
    }
}
