//
//  OnboardingPageView.swift
//  SafeEats
//

import SwiftUI

/// A single onboarding page.
///
/// Handles all three shapes of page from the content file without needing a
/// separate view for each: image and body, body plus numbered steps, and the
/// long terms of use.
struct OnboardingPageView: View {
    let page: OnboardingContent.Page

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if let assetName = page.imageAssetName, !assetName.isEmpty {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                if !page.steps.isEmpty {
                    stepList
                }

                if !page.paragraphs.isEmpty {
                    paragraphList
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            // Leaves room for the page indicator and the agree button.
            .padding(.bottom, 72)
            .frame(maxWidth: .infinity)
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(page.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.accentColor))

                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .panelBackground(cornerRadius: 12)
    }

    private var paragraphList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(page.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index + 1).")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                    Text(paragraph)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .panelBackground(cornerRadius: 12)
    }
}
