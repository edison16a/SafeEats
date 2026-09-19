//
//  MainTabView.swift
//  SafeEats
//

import SwiftUI

/// Hosts the three screens and the custom tab bar.
///
/// The original branched on `UIDevice.userInterfaceIdiom` to build two
/// identical hierarchies, one wrapped in `NavigationStack` and one in the
/// deprecated `NavigationView`. Neither pushed anything, so both are gone;
/// each screen supplies its own heading.
struct MainTabView: View {
    let dependencies: AppDependencies

    @State private var selection: AppTab = .scan

    var body: some View {
        VStack(spacing: 12) {
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppTabBar(selection: $selection)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var screen: some View {
        switch selection {
        case .scan:
            ScanScreen(model: dependencies.scanModel)

        case .allergens:
            AllergenScreen(
                catalog: dependencies.repository.catalog,
                profile: dependencies.profile,
                onSelectionChanged: { dependencies.scanModel.reevaluateLastScan() }
            )

        case .styles:
            ThemeScreen(preference: dependencies.theme)
        }
    }
}
