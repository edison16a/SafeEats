//
//  LaunchPlaceholderView.swift
//  SafeEats
//

import SwiftUI

/// Shown for the moment it takes to decode the bundled allergen data.
struct LaunchPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        }
    }
}
