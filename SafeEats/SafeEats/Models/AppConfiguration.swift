//
//  AppConfiguration.swift
//  SafeEats
//
//  Decoded form of `AppConfiguration.json`.
//

import Foundation

/// Links and settings that would otherwise be hard-coded into a view.
struct AppConfiguration: Sendable, Decodable {
    let schemaVersion: Int

    /// Where the "allergen not listed" button sends people.
    ///
    /// Held as a string rather than a `URL` on purpose. If someone mistypes it
    /// in the resource file, the button quietly disappears instead of the whole
    /// app refusing to start, which is what decoding straight into `URL` would
    /// do.
    let allergenRequestFormURL: String

    /// The parsed request form link, or `nil` if the resource holds a bad URL.
    var allergenRequestForm: URL? {
        URL(string: allergenRequestFormURL)
    }
}
