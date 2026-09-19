//
//  AppTheme.swift
//  SafeEats
//
//  Decoded form of `Themes.json`.
//

import SwiftUI
import OSLog

/// A color in a theme: either a SwiftUI system color by name, or a hex literal.
///
/// System colors are kept as names rather than being flattened to hex so they
/// keep adapting to the platform the way `Color.purple` does.
enum ThemeColor: Hashable, Sendable {
    case system(String)
    case hex(String)

    /// The resolved SwiftUI color, falling back to gray for an unknown name.
    var color: Color {
        switch self {
        case .system(let name):
            if let match = Self.systemColors[name.lowercased()] {
                return match
            }
            Log.resources.error("Unknown system color '\(name, privacy: .public)' in Themes.json")
            return .gray

        case .hex(let value):
            if let match = Color(hex: value) {
                return match
            }
            Log.resources.error("Invalid hex color '\(value, privacy: .public)' in Themes.json")
            return .gray
        }
    }

    private static let systemColors: [String: Color] = [
        "black": .black, "blue": .blue, "brown": .brown, "clear": .clear,
        "cyan": .cyan, "gray": .gray, "green": .green, "indigo": .indigo,
        "mint": .mint, "orange": .orange, "pink": .pink, "purple": .purple,
        "red": .red, "teal": .teal, "white": .white, "yellow": .yellow
    ]
}

extension ThemeColor: Decodable {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw.hasPrefix("#") ? .hex(raw) : .system(raw)
    }
}

/// A background style the user can pick on the Styles tab.
///
/// Previously the 21 styles were written out twice — once as a `switch` that
/// built the background and once as an array of preview swatches — so a change
/// to one had to be mirrored by hand in the other. Both now read this.
struct AppTheme: Identifiable, Hashable, Sendable {
    /// Where a gradient starts and ends.
    enum GradientPoint: String, Sendable, Decodable {
        case top, bottom, leading, trailing, center
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var unitPoint: UnitPoint {
            switch self {
            case .top: return .top
            case .bottom: return .bottom
            case .leading: return .leading
            case .trailing: return .trailing
            case .center: return .center
            case .topLeading: return .topLeading
            case .topTrailing: return .topTrailing
            case .bottomLeading: return .bottomLeading
            case .bottomTrailing: return .bottomTrailing
            }
        }
    }

    let id: String
    /// Name shown in the style list.
    let name: String
    /// One-line description shown under the name.
    let detail: String
    let colors: [ThemeColor]
    let startPoint: GradientPoint
    let endPoint: GradientPoint

    /// True when the theme is a single flat fill rather than a gradient.
    var isFlat: Bool { colors.count < 2 }
}

extension AppTheme: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name, detail, colors, startPoint, endPoint
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.detail = try container.decode(String.self, forKey: .detail)
        self.colors = try container.decode([ThemeColor].self, forKey: .colors)
        // Flat themes omit the gradient endpoints entirely.
        self.startPoint = try container.decodeIfPresent(GradientPoint.self, forKey: .startPoint) ?? .top
        self.endPoint = try container.decodeIfPresent(GradientPoint.self, forKey: .endPoint) ?? .bottom
    }
}

/// The decoded contents of `Themes.json`.
struct ThemeCollection: Sendable, Decodable {
    let schemaVersion: Int
    /// Id of the theme used until the user picks one.
    let defaultThemeID: String
    let themes: [AppTheme]

    /// The default theme, or the first one if the id does not resolve.
    var defaultTheme: AppTheme? {
        themes.first { $0.id == defaultThemeID } ?? themes.first
    }

    func theme(with id: String) -> AppTheme? {
        themes.first { $0.id == id }
    }
}
