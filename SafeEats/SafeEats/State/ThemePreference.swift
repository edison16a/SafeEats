//
//  ThemePreference.swift
//  SafeEats
//

import Foundation
import Observation

/// The background style the user has chosen, and the list to choose from.
///
/// The selection is persisted; previously it lived in `@State` on the root view
/// and was forgotten every time the app relaunched.
@MainActor
@Observable
final class ThemePreference {
    /// Every theme defined in `Themes.json`, in file order.
    let themes: [AppTheme]

    /// The theme currently applied.
    private(set) var selected: AppTheme

    @ObservationIgnored
    private let defaults: UserDefaults

    private static let storageKey = "selectedThemeID"

    /// - Parameters:
    ///   - collection: Decoded `Themes.json`.
    ///   - defaults: Storage for the selection.
    init(collection: ThemeCollection, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.themes = collection.themes

        let storedID = defaults.string(forKey: Self.storageKey)
        let resolved = storedID.flatMap(collection.theme(with:))
            ?? collection.defaultTheme
            ?? Self.fallbackTheme

        self.selected = resolved
    }

    func select(_ theme: AppTheme) {
        guard theme.id != selected.id else { return }
        selected = theme
        defaults.set(theme.id, forKey: Self.storageKey)
    }

    func isSelected(_ theme: AppTheme) -> Bool {
        theme.id == selected.id
    }

    /// Used only if `Themes.json` somehow contains no themes at all, so that the
    /// app still renders something legible instead of crashing.
    private static let fallbackTheme = AppTheme(
        id: "fallback",
        name: "Charcoal",
        detail: "Default background.",
        colors: [.hex("#2e2e2e"), .hex("#000000")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
