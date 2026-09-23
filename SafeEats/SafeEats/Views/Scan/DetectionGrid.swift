//
//  DetectionGrid.swift
//  SafeEats
//

import SwiftUI

/// The grid of allergens found by the last scan.
struct DetectionGrid: View {
    let detections: [AllergenDetection]

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(detections) { detection in
                DetectionChip(detection: detection)
            }
        }
    }
}

/// One allergen result: icon, name, and the keyword that triggered it.
///
/// Showing the matched term is what makes a broad match defensible. A chip
/// reading "Soy, E322" lets the user see the app matched an additive code
/// rather than the word "soy", and decide for themselves.
struct DetectionChip: View {
    let detection: AllergenDetection

    var body: some View {
        VStack(spacing: 6) {
            Image(detection.allergen.iconAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)

            Text(detection.allergen.name)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)

            if let term = detection.headlineTerm {
                Text(term.text)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(detection.severity.tint.opacity(0.9))
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: detection.severity.symbolName)
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [detection.allergen.name, detection.severity.accessibilityDescription]
        if let term = detection.headlineTerm {
            parts.append("matched “\(term.text)”")
            if let note = term.note {
                parts.append(note)
            }
        }
        return parts.joined(separator: ". ")
    }
}
