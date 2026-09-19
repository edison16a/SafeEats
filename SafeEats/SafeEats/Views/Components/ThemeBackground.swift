//
//  ThemeBackground.swift
//  SafeEats
//

import SwiftUI

/// Renders an ``AppTheme`` as a flat fill or a linear gradient.
///
/// One view draws both the app background and the swatches in the style picker,
/// so a preview can never drift out of step with what applying it actually does.
struct ThemeBackground: View {
    let theme: AppTheme

    var body: some View {
        if let single = theme.colors.first, theme.isFlat {
            single.color
        } else if theme.colors.isEmpty {
            Color.black
        } else {
            LinearGradient(
                colors: theme.colors.map(\.color),
                startPoint: theme.startPoint.unitPoint,
                endPoint: theme.endPoint.unitPoint
            )
        }
    }
}

/// A frosted panel that keeps text legible over any theme, however bright.
struct PanelBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

extension View {
    /// Places the view on a translucent dark panel.
    func panelBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(PanelBackground(cornerRadius: cornerRadius))
    }
}
