//
//  Color+Hex.swift
//  SafeEats
//

import SwiftUI

extension Color {
    /// Creates a color from a hex string such as `"#2e2e2e"`, `"2e2e2e"` or `"#2e2e2eff"`.
    ///
    /// Returns `nil` for anything that is not 6 or 8 hex digits, so a typo in a
    /// theme resource surfaces as a logged fallback instead of silently
    /// rendering black — which is what the previous non-failable initializer did
    /// whenever the string still carried its leading `#`.
    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }

        guard digits.count == 6 || digits.count == 8,
              digits.allSatisfy(\.isHexDigit),
              let value = UInt64(digits, radix: 16) else {
            return nil
        }

        let hasAlpha = digits.count == 8
        let red = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
