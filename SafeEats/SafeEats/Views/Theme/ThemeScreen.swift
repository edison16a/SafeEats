//
//  ThemeScreen.swift
//  SafeEats
//

import SwiftUI

/// The Styles tab: pick the app's background.
struct ThemeScreen: View {
    let preference: ThemePreference

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Styles")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose a background for SafeEats.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 4)

                ForEach(preference.themes) { theme in
                    ThemeRow(
                        theme: theme,
                        isSelected: preference.isSelected(theme),
                        action: { preference.select(theme) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

/// One selectable style: a live swatch, its name and description.
///
/// The swatch is rendered by the same ``ThemeBackground`` that paints the app,
/// so a preview cannot disagree with the result of tapping it.
private struct ThemeRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ThemeBackground(theme: theme)
                    .frame(width: 56, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(theme.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.4))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelBackground(cornerRadius: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityValue(theme.detail)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}
