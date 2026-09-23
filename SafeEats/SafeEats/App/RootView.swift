//
//  RootView.swift
//  SafeEats
//

import SwiftUI

/// Loads the app's resources, then shows either onboarding or the main tabs.
///
/// Loading happens once the view appears rather than in an initializer, so that
/// a missing or malformed resource can be reported in the UI instead of
/// trapping at launch.
struct RootView: View {
    /// Progress of the one-time resource load.
    private enum LoadState {
        case loading
        case ready(AppDependencies)
        case failed(String)
    }

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var loadState: LoadState = .loading

    var body: some View {
        content
            // Loading is synchronous file I/O and JSON decoding, so `onAppear`
            // is enough; there is nothing to await.
            .onAppear {
                guard case .loading = loadState else { return }
                loadState = Self.loadDependencies()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            LaunchPlaceholderView()

        case .failed(let message):
            ResourceFailureView(message: message)

        case .ready(let dependencies):
            ZStack {
                ThemeBackground(theme: dependencies.theme.selected)
                    .ignoresSafeArea()

                if hasSeenOnboarding {
                    MainTabView(dependencies: dependencies)
                } else {
                    OnboardingScreen(content: dependencies.onboarding) {
                        hasSeenOnboarding = true
                    }
                }
            }
        }
    }

    @MainActor
    private static func loadDependencies() -> LoadState {
        do {
            return .ready(try AppDependencies())
        } catch {
            Log.resources.critical(
                "Startup failed: \(error.localizedDescription, privacy: .public)"
            )
            return .failed(error.localizedDescription)
        }
    }
}
