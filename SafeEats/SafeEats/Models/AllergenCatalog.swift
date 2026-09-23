//
//  AllergenCatalog.swift
//  SafeEats
//
//  Decoded form of `AllergenCatalog.json`.
//

import Foundation

/// A heading the allergen list is grouped under, such as "Common Allergens".
struct AllergenCategory: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    /// Section heading shown above the group.
    let title: String
    /// One line of explanation shown beneath the heading.
    let subtitle: String
}

/// One allergen the app can look for.
///
/// This is metadata only. The words that identify the allergen on a label live
/// in a separate resource named by ``keywordResourceName``, loaded on demand by
/// ``AllergenRepository``.
struct Allergen: Identifiable, Hashable, Sendable, Decodable {
    let id: AllergenID
    /// Human-readable name, e.g. "Tree Nut".
    let name: String
    /// The ``AllergenCategory`` this allergen is listed under.
    let categoryID: AllergenCategory.ID
    /// Name of the image set in the asset catalog.
    let iconAssetName: String
    /// Base name of the JSON resource holding this allergen's keywords.
    let keywordResourceName: String
}

/// The full list of allergens the app knows about, in display order.
struct AllergenCatalog: Sendable, Decodable {
    /// Version of the on-disk format, so a future migration can branch on it.
    let schemaVersion: Int
    let categories: [AllergenCategory]
    let allergens: [Allergen]

    /// A category paired with the allergens that belong to it.
    struct Section: Identifiable, Hashable, Sendable {
        let category: AllergenCategory
        let allergens: [Allergen]

        var id: AllergenCategory.ID { category.id }
    }

    /// Allergens grouped for display, in catalog order, skipping empty categories.
    var sections: [Section] {
        categories.compactMap { category in
            let members = allergens.filter { $0.categoryID == category.id }
            return members.isEmpty ? nil : Section(category: category, allergens: members)
        }
    }

    /// Looks up a single allergen, or `nil` if the id is not in the catalog.
    func allergen(with id: AllergenID) -> Allergen? {
        allergens.first { $0.id == id }
    }
}
