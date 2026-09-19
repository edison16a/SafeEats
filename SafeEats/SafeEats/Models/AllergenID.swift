//
//  AllergenID.swift
//  SafeEats
//

import Foundation

/// A stable identifier for an allergen, e.g. `"peanut"` or `"treeNut"`.
///
/// Wrapping the raw string keeps allergen ids from being mixed up with the
/// other strings flying around the detector — asset names, keyword text,
/// category ids — all of which are also `String`.
///
/// The identifier doubles as the name of the allergen's image set in the asset
/// catalog; see ``Allergen/iconAssetName``.
struct AllergenID: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    var description: String { rawValue }
}

// Coded as a bare string rather than the `{"rawValue": …}` object that Codable
// synthesis would produce for a struct, so the JSON stays readable.
extension AllergenID: Codable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
