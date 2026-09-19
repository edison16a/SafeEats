//
//  AllergenProfile.swift
//  SafeEats
//

import Foundation
import Observation
import OSLog

/// The set of allergens the user has asked to be warned about.
///
/// Persisted to `UserDefaults` as a plain array of ids. The previous version
/// stored the entire allergen list — names, icons and all — re-encoded on every
/// toggle, which meant a rename in the catalog silently resurrected stale copies
/// of the old entries. See ``migrateLegacySelectionIfNeeded(in:)`` for how
/// existing installs are carried across.
@MainActor
@Observable
final class AllergenProfile {
    /// Ids of the allergens the user wants flagged.
    private(set) var enabledIDs: Set<AllergenID>

    @ObservationIgnored
    private let defaults: UserDefaults

    private enum Key {
        static let enabledIDs = "enabledAllergenIDs"
        /// Written by SafeEats 1.1 and earlier.
        static let legacySelection = "selectedAllergens"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabledIDs = Self.loadEnabledIDs(from: defaults)
    }

    /// Whether `id` is one of the user's allergens.
    func isEnabled(_ id: AllergenID) -> Bool {
        enabledIDs.contains(id)
    }

    /// Switches an allergen on or off and saves immediately.
    func setEnabled(_ isEnabled: Bool, for id: AllergenID) {
        let updated = isEnabled ? enabledIDs.union([id]) : enabledIDs.subtracting([id])
        guard updated != enabledIDs else { return }
        enabledIDs = updated
        save()
    }

    func toggle(_ id: AllergenID) {
        setEnabled(!isEnabled(id), for: id)
    }

    /// Clears every selection.
    func removeAll() {
        guard !enabledIDs.isEmpty else { return }
        enabledIDs = []
        save()
    }

    private func save() {
        defaults.set(enabledIDs.map(\.rawValue).sorted(), forKey: Key.enabledIDs)
    }

    // MARK: - Loading

    private static func loadEnabledIDs(from defaults: UserDefaults) -> Set<AllergenID> {
        if let stored = defaults.stringArray(forKey: Key.enabledIDs) {
            return Set(stored.map(AllergenID.init(rawValue:)))
        }
        return migrateLegacySelectionIfNeeded(in: defaults)
    }

    /// Reads the SafeEats 1.1 selection format and rewrites it in the current one.
    ///
    /// 1.1 stored a JSON array of full allergen records under
    /// `selectedAllergens`; only the enabled ones matter now. The legacy key is
    /// left in place so downgrading does not lose the user's choices.
    private static func migrateLegacySelectionIfNeeded(in defaults: UserDefaults) -> Set<AllergenID> {
        /// Minimal view of a 1.1 record — the other fields are no longer used.
        struct LegacyRecord: Decodable {
            let id: String
            let isEnabled: Bool
        }

        guard let data = defaults.data(forKey: Key.legacySelection), !data.isEmpty else {
            return []
        }

        guard let records = try? JSONDecoder().decode([LegacyRecord].self, from: data) else {
            Log.resources.warning("Could not read the saved allergen selection; starting empty.")
            return []
        }

        let migrated = Set(records.filter(\.isEnabled).map { AllergenID(rawValue: $0.id) })
        defaults.set(migrated.map(\.rawValue).sorted(), forKey: Key.enabledIDs)
        Log.resources.info("Migrated \(migrated.count) saved allergen selections.")
        return migrated
    }
}
