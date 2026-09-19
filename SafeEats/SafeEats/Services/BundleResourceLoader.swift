//
//  BundleResourceLoader.swift
//  SafeEats
//

import Foundation
import OSLog

/// Loads and decodes the app's bundled JSON resources.
///
/// Xcode's synchronized project groups copy loose resources into the bundle
/// root, but a folder reference preserves its directory structure. Rather than
/// depend on which one a given project configuration produces, the loader tries
/// the bundle root first and then each known subdirectory.
struct BundleResourceLoader: Sendable {
    enum LoaderError: LocalizedError {
        case resourceNotFound(name: String, fileExtension: String)
        case decodingFailed(name: String, underlying: any Error)

        var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name, let fileExtension):
                return "Could not find the bundled resource ‘\(name).\(fileExtension)’."
            case .decodingFailed(let name, let underlying):
                return "Could not read the bundled resource ‘\(name)’: \(underlying.localizedDescription)"
            }
        }
    }

    private let bundle: Bundle
    private let subdirectories: [String?]

    /// The loader used by the running app.
    static let main = BundleResourceLoader(bundle: .main)

    /// - Parameters:
    ///   - bundle: Bundle to search. Tests pass their own.
    ///   - subdirectories: Paths to try, in order. `nil` means the bundle root.
    init(
        bundle: Bundle,
        subdirectories: [String?] = [nil, "Resources", "Resources/Keywords", "Keywords"]
    ) {
        self.bundle = bundle
        self.subdirectories = subdirectories
    }

    /// Decodes a bundled JSON resource.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - name: Resource name without its extension, e.g. `"AllergenCatalog"`.
    /// - Throws: ``LoaderError`` if the file is missing or malformed.
    func load<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        guard let url = url(forResource: name, fileExtension: "json") else {
            throw LoaderError.resourceNotFound(name: name, fileExtension: "json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Log.resources.error(
                "Failed to decode \(name, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw LoaderError.decodingFailed(name: name, underlying: error)
        }
    }

    private func url(forResource name: String, fileExtension: String) -> URL? {
        for subdirectory in subdirectories {
            if let url = bundle.url(
                forResource: name,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return nil
    }
}
