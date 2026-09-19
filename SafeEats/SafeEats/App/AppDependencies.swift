//
//  AppDependencies.swift
//  SafeEats
//

import Foundation
import OSLog

/// The app's composition root.
///
/// Everything that needs wiring together is built here, once, and handed to the
/// views. Nothing below this point reaches for a singleton or loads a resource
/// on its own, which is what lets the detector and the stores be exercised in
/// tests with their own fixtures.
@MainActor
final class AppDependencies {
    /// Allergen catalog, keyword index and the detector built from them.
    let repository: AllergenRepository
    /// Copy for the first-run walkthrough.
    let onboarding: OnboardingContent
    /// The user's allergen selections.
    let profile: AllergenProfile
    /// The user's chosen background style.
    let theme: ThemePreference
    /// State for the Scan tab, including the capture session.
    let scanModel: ScanModel

    private enum ResourceName {
        static let themes = "Themes"
        static let onboarding = "OnboardingContent"
    }

    /// Loads every bundled resource and wires the object graph.
    ///
    /// - Throws: ``BundleResourceLoader/LoaderError`` if any resource is missing
    ///   or malformed. ``RootView`` turns that into an explanatory screen rather
    ///   than letting the app trap.
    init(
        loader: BundleResourceLoader = .main,
        defaults: UserDefaults = .standard
    ) throws {
        let repository = try AllergenRepository(loader: loader)
        let themes = try loader.load(ThemeCollection.self, named: ResourceName.themes)
        let onboarding = try loader.load(OnboardingContent.self, named: ResourceName.onboarding)
        let profile = AllergenProfile(defaults: defaults)

        self.repository = repository
        self.onboarding = onboarding
        self.profile = profile
        self.theme = ThemePreference(collection: themes, defaults: defaults)
        self.scanModel = ScanModel(detector: repository.detector, profile: profile)

        Log.resources.info("SafeEats dependencies ready.")
    }
}
