//
//  AppTabBar.swift
//  SafeEats
//

import SwiftUI

/// The three top-level destinations.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case scan
    case allergens
    case styles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan: return "Scan"
        case .allergens: return "Allergens"
        case .styles: return "Styles"
        }
    }

    /// SF Symbol shown when the tab is not selected.
    var symbolName: String {
        switch self {
        case .scan: return "camera"
        case .allergens: return "exclamationmark.shield"
        case .styles: return "paintpalette"
        }
    }

    /// Filled SF Symbol shown when the tab is selected.
    var selectedSymbolName: String { symbolName + ".fill" }
}

/// Custom bottom tab bar.
///
/// Drawn on the same dark panel as the rest of the chrome so that the labels
/// stay legible over every theme, including the bright ones. Unlike the
/// original it also marks the selected tab — previously both states were plain
/// white, leaving no way to tell which tab you were on — and reports selection
/// to VoiceOver.
struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: tab == selection,
                    action: { selection = tab }
                )
            }
        }
        .padding(.vertical, 8)
        .panelBackground(cornerRadius: 18)
        .padding(.horizontal, 16)
    }
}

private struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedSymbolName : tab.symbolName)
                    .font(.system(size: 22))
                Text(tab.title)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}
