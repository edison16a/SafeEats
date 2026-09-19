//
//  DetectionSeverity+Presentation.swift
//  SafeEats
//

import SwiftUI

/// How each severity is presented.
///
/// Kept beside the views rather than on the model so that ``DetectionSeverity``
/// stays free of SwiftUI and can be tested without it.
extension DetectionSeverity {
    var tint: Color {
        switch self {
        case .avoid: return .red
        case .advisory: return .orange
        case .informational: return .green
        }
    }

    var symbolName: String {
        switch self {
        case .avoid: return "xmark.octagon.fill"
        case .advisory: return "exclamationmark.triangle.fill"
        case .informational: return "checkmark.circle.fill"
        }
    }

    /// Short label used on chips and in section headings.
    var title: String {
        switch self {
        case .avoid: return "Avoid"
        case .advisory: return "May contain"
        case .informational: return "Not yours"
        }
    }

    /// Spoken description, so VoiceOver conveys the colour coding.
    var accessibilityDescription: String {
        switch self {
        case .avoid: return "One of your allergens, listed in the ingredients"
        case .advisory: return "One of your allergens, listed as may contain"
        case .informational: return "Found on the label, not one of your allergens"
        }
    }
}
