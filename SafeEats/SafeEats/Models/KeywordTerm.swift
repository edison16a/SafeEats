//
//  KeywordTerm.swift
//  SafeEats
//

import Foundation

/// What kind of thing a keyword names, which the UI uses to explain a match.
enum KeywordKind: String, Hashable, Sendable, Decodable {
    /// A word that appears in an ingredient list, e.g. "whey", "Vollmilch".
    case ingredient
    /// A European additive number, e.g. "E322".
    case additiveCode
    /// A binomial name, e.g. "Prunus persica".
    case scientificName
    /// A named chemical or protein, e.g. "Tropomyosin".
    case compound
}

/// A single word or phrase that indicates an allergen is present.
///
/// Decodes from either form so the resource files stay readable. The vast
/// majority of terms need nothing but their text:
///
/// ```json
/// "whey"
/// { "text": "E322", "kind": "additiveCode", "note": "soy lecithin code" }
/// ```
struct KeywordTerm: Hashable, Sendable {
    /// The term as written, e.g. "Leche entera". Folded for matching at index time.
    let text: String
    let kind: KeywordKind
    /// Optional gloss shown to the user, e.g. "sodium nitrite - used in processed meats".
    let note: String?

    init(text: String, kind: KeywordKind = .ingredient, note: String? = nil) {
        self.text = text
        self.kind = kind
        self.note = note
    }
}

extension KeywordTerm: Decodable {
    private enum CodingKeys: String, CodingKey {
        case text, kind, note
    }

    init(from decoder: any Decoder) throws {
        // Shorthand form: a bare JSON string.
        if let single = try? decoder.singleValueContainer(),
           let text = try? single.decode(String.self) {
            self.init(text: text)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            text: try container.decode(String.self, forKey: .text),
            kind: try container.decodeIfPresent(KeywordKind.self, forKey: .kind) ?? .ingredient,
            note: try container.decodeIfPresent(String.self, forKey: .note)
        )
    }
}

/// Every keyword that identifies one allergen, grouped by language.
///
/// Decoded from `AllergenKeywords-<id>.json`.
struct AllergenKeywordSet: Sendable, Decodable {
    /// Keywords sharing a language.
    struct Group: Sendable, Decodable {
        /// BCP-47 style language code, or `"und"` for terms that belong to no
        /// single language such as additive codes and binomial names.
        let language: String
        let terms: [KeywordTerm]
    }

    let schemaVersion: Int
    let allergenID: AllergenID
    let groups: [Group]

    /// Every term across every language group.
    var allTerms: [KeywordTerm] {
        groups.flatMap(\.terms)
    }
}
