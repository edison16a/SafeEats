//
//  ScanResultsPanel.swift
//  SafeEats
//

import SwiftUI

/// Results of the last scan, or an explanation of why there aren't any.
///
/// There are three different kinds of nothing here, and they need different
/// advice: no scan yet, a scan that read no text, and a scan that read text but
/// matched no keywords. Collapsing them into one empty state would leave people
/// guessing whether to move the camera or trust the label.
struct ScanResultsPanel: View {
    let result: ScanResult
    let hasScanned: Bool
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !hasScanned {
                emptyState(
                    "Nothing scanned yet",
                    detail: "Tap Scan Now with a label in view."
                )
            } else if result.isEmpty {
                emptyState(
                    "No text was read",
                    detail: "Try moving closer, steadying the camera, or improving the lighting."
                )
            } else if result.detections.isEmpty {
                emptyState(
                    "No known allergens found",
                    detail: "SafeEats did not recognise any of its keywords on this label. Check the packaging yourself."
                )
            } else {
                DetectionGrid(detections: result.detections)
                SeverityLegend()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelBackground()
    }

    private var header: some View {
        HStack {
            Text("Allergens Detected")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            if hasScanned {
                Button("Clear", action: onClear)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

/// Explains the three result colours.
///
/// Hidden from VoiceOver because each chip already says its own severity out
/// loud, so reading the key as well would just be noise.
struct SeverityLegend: View {
    private let severities: [DetectionSeverity] = [.avoid, .advisory, .informational]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(severities, id: \.self) { severity in
                HStack(spacing: 5) {
                    Circle()
                        .fill(severity.tint)
                        .frame(width: 9, height: 9)
                    Text(severity.title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }
}
