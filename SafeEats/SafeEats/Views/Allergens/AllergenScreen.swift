//
//  AllergenScreen.swift
//  SafeEats
//

import SwiftUI

/// The Allergens tab: pick which allergens SafeEats should warn about.
///
/// Grouped by the categories declared in `AllergenCatalog.json`, rather than
/// the single flat list of 23 toggles the original presented.
struct AllergenScreen: View {
    let catalog: AllergenCatalog
    let profile: AllergenProfile
    /// Called after a toggle changes, so the Scan tab can re-score its last result.
    let onSelectionChanged: () -> Void

    /// Where users can ask for an allergen that is not in the catalog.
    private static let requestFormURL = URL(string: "https://forms.gle/Ehd5V2Vcz9wqbQnL6")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(catalog.sections) { section in
                    categorySection(section)
                }

                requestButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Allergens")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text(selectionSummary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionSummary: String {
        let count = profile.enabledIDs.count
        switch count {
        case 0: return "Switch on the allergens you need to avoid."
        case 1: return "1 allergen selected."
        default: return "\(count) allergens selected."
        }
    }

    private func categorySection(_ section: AllergenCatalog.Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.category.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(section.category.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            VStack(spacing: 8) {
                ForEach(section.allergens) { allergen in
                    AllergenToggleRow(
                        allergen: allergen,
                        isOn: binding(for: allergen)
                    )
                }
            }
        }
    }

    private var requestButton: some View {
        Group {
            if let url = Self.requestFormURL {
                Link(destination: url) {
                    Label("Allergen not listed? Request it", systemImage: "plus.bubble")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
            }
        }
        .padding(.top, 4)
    }

    /// Bridges a single allergen's on/off state to ``AllergenProfile``.
    private func binding(for allergen: Allergen) -> Binding<Bool> {
        Binding(
            get: { profile.isEnabled(allergen.id) },
            set: { isOn in
                profile.setEnabled(isOn, for: allergen.id)
                onSelectionChanged()
            }
        )
    }
}
