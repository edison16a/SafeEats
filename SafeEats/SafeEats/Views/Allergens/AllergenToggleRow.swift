//
//  AllergenToggleRow.swift
//  SafeEats
//

import SwiftUI

/// One row in the allergen list: icon, name and a switch.
struct AllergenToggleRow: View {
    let allergen: Allergen
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(allergen.iconAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)

                Text(allergen.name)
                    .font(.body)
                    .foregroundStyle(.white)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .panelBackground(cornerRadius: 12)
        .accessibilityLabel(allergen.name)
        .accessibilityHint("Warn me when \(allergen.name.lowercased()) is found on a label.")
    }
}
