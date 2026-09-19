//
//  OnboardingScreen.swift
//  SafeEats
//

import SwiftUI

/// The first-run walkthrough, ending with the terms of use.
///
/// Pages and their copy come from `OnboardingContent.json`; the acknowledgement
/// button appears on whichever page is flagged there, instead of on a
/// hard-coded page index.
struct OnboardingScreen: View {
    let content: OnboardingContent
    /// Called when the user accepts the terms.
    let onAcknowledge: () -> Void

    @State private var selection: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                ForEach(Array(content.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if showsAcknowledgement {
                Button(action: onAcknowledge) {
                    Text(content.acknowledgementButtonTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsAcknowledgement)
    }

    /// True when the visible page is the one that carries the agree button.
    private var showsAcknowledgement: Bool {
        selection == content.acknowledgementPageIndex
    }
}
