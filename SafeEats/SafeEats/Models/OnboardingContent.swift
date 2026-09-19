//
//  OnboardingContent.swift
//  SafeEats
//
//  Decoded form of `OnboardingContent.json`.
//

import Foundation

/// Copy for the first-run walkthrough, including the terms of use.
///
/// Keeping this in a resource means the terms can be corrected without touching
/// the view, and means the view no longer has to hard-code "the agree button
/// belongs on page index 3".
struct OnboardingContent: Sendable, Decodable {
    struct Page: Identifiable, Hashable, Sendable, Decodable {
        let id: String
        let title: String
        /// Asset-catalog image shown above the body, if the page has one.
        let imageAssetName: String?
        let body: String
        /// Numbered instructions, rendered as an ordered list.
        let steps: [String]
        /// Free-standing paragraphs, used for the terms of use.
        let paragraphs: [String]
        /// When true, this page shows the button that dismisses onboarding.
        let requiresAcknowledgement: Bool

        private enum CodingKeys: String, CodingKey {
            case id, title, imageAssetName, body, steps, paragraphs, requiresAcknowledgement
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(String.self, forKey: .id)
            self.title = try container.decode(String.self, forKey: .title)
            self.imageAssetName = try container.decodeIfPresent(String.self, forKey: .imageAssetName)
            self.body = try container.decode(String.self, forKey: .body)
            self.steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []
            self.paragraphs = try container.decodeIfPresent([String].self, forKey: .paragraphs) ?? []
            self.requiresAcknowledgement =
                try container.decodeIfPresent(Bool.self, forKey: .requiresAcknowledgement) ?? false
        }
    }

    let schemaVersion: Int
    /// Title of the button that completes onboarding.
    let acknowledgementButtonTitle: String
    let pages: [Page]

    /// Index of the page carrying the acknowledgement button, if any.
    var acknowledgementPageIndex: Int? {
        pages.firstIndex(where: \.requiresAcknowledgement)
    }
}
