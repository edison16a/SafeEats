//
//  ResourceFailureView.swift
//  SafeEats
//

import SwiftUI

/// Shown when a bundled resource is missing or malformed.
///
/// Only reachable from a broken build, so the wording is aimed at whoever is
/// debugging it as much as at the person holding the phone.
struct ResourceFailureView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.yellow)

                Text("SafeEats could not start")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Text("The app's allergen data is missing from this build. Please reinstall SafeEats.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
    }
}
