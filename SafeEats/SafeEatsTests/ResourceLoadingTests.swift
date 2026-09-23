//
//  ResourceLoadingTests.swift
//  SafeEatsTests
//

import Foundation
import SwiftUI
import Testing
@testable import SafeEats

@Suite("Resource decoding")
struct ResourceDecodingTests {

    @Test("Keyword terms decode from both the short and the long form")
    func keywordTermDecoding() throws {
        let json = Data("""
        ["milk", {"text": "E322", "kind": "additiveCode", "note": "soy lecithin code"}]
        """.utf8)

        let terms = try JSONDecoder().decode([KeywordTerm].self, from: json)

        #expect(terms.count == 2)
        #expect(terms[0] == KeywordTerm(text: "milk", kind: .ingredient, note: nil))
        #expect(terms[1].text == "E322")
        #expect(terms[1].kind == .additiveCode)
        #expect(terms[1].note == "soy lecithin code")
    }

    @Test("Allergen ids encode as bare strings")
    func allergenIDCoding() throws {
        let encoded = try JSONEncoder().encode(AllergenID("treeNut"))
        #expect(String(decoding: encoded, as: UTF8.self) == "\"treeNut\"")

        let decoded = try JSONDecoder().decode(AllergenID.self, from: Data("\"peanut\"".utf8))
        #expect(decoded == AllergenID("peanut"))
    }

    @Test("Themes decode system names and hex literals")
    func themeColorDecoding() throws {
        let json = Data("""
        {
          "id": "test", "name": "Test", "detail": "A theme",
          "colors": ["purple", "#2e2e2e"],
          "startPoint": "topLeading", "endPoint": "bottomTrailing"
        }
        """.utf8)

        let theme = try JSONDecoder().decode(AppTheme.self, from: json)

        #expect(theme.colors == [.system("purple"), .hex("#2e2e2e")])
        #expect(theme.startPoint == .topLeading)
        #expect(!theme.isFlat)
    }

    @Test("A theme with one color and no endpoints is flat")
    func flatThemeDecoding() throws {
        let json = Data("""
        {"id": "mint", "name": "Mint", "detail": "Flat", "colors": ["mint"]}
        """.utf8)

        let theme = try JSONDecoder().decode(AppTheme.self, from: json)

        #expect(theme.isFlat)
        #expect(theme.colors == [.system("mint")])
    }

    @Test("Optional onboarding fields default rather than failing")
    func onboardingPageDefaults() throws {
        let json = Data("""
        {"id": "welcome", "title": "Hi", "body": "Body text"}
        """.utf8)

        let page = try JSONDecoder().decode(OnboardingContent.Page.self, from: json)

        #expect(page.steps.isEmpty)
        #expect(page.paragraphs.isEmpty)
        #expect(page.imageAssetName == nil)
        #expect(page.requiresAcknowledgement == false)
    }

    @Test("A bad link in the configuration disables the button instead of throwing")
    func configurationToleratesABadLink() throws {
        let json = Data("""
        {"schemaVersion": 1, "allergenRequestFormURL": ""}
        """.utf8)

        let configuration = try JSONDecoder().decode(AppConfiguration.self, from: json)

        // Decoding must succeed so the app still starts; the link just goes away.
        #expect(configuration.allergenRequestForm == nil)
    }

    @Test("A good link in the configuration parses")
    func configurationParsesALink() throws {
        let json = Data("""
        {"schemaVersion": 1, "allergenRequestFormURL": "https://example.com/form"}
        """.utf8)

        let configuration = try JSONDecoder().decode(AppConfiguration.self, from: json)

        #expect(configuration.allergenRequestForm?.absoluteString == "https://example.com/form")
    }

    @Test("Hex colors are rejected when malformed")
    func hexParsing() {
        #expect(Color(hex: "#2e2e2e") != nil)
        #expect(Color(hex: "2e2e2e") != nil)
        #expect(Color(hex: "#2e2e2eff") != nil)
        #expect(Color(hex: "#xyz") == nil)
        #expect(Color(hex: "") == nil)
    }
}

@Suite("Shipped resources")
struct ShippedResourceTests {

    /// The tests are hosted by the app, so `Bundle.main` is the app bundle and
    /// the real JSON resources are reachable.
    private let loader = BundleResourceLoader.main

    @Test("The full repository loads from the app bundle")
    func repositoryLoads() throws {
        let repository = try AllergenRepository(loader: loader)

        #expect(repository.catalog.allergens.count == 23)
        #expect(repository.keywordIndex.count > 1_000)
    }

    @Test("Every allergen belongs to a declared category")
    func categoriesResolve() throws {
        let repository = try AllergenRepository(loader: loader)
        let categoryIDs = Set(repository.catalog.categories.map(\.id))

        for allergen in repository.catalog.allergens {
            #expect(categoryIDs.contains(allergen.categoryID), "\(allergen.id) has an unknown category")
        }
    }

    @Test("Sections account for every allergen exactly once")
    func sectionsArePartition() throws {
        let repository = try AllergenRepository(loader: loader)
        let sectioned = repository.catalog.sections.flatMap(\.allergens).map(\.id)

        #expect(Set(sectioned) == Set(repository.catalog.allergens.map(\.id)))
        #expect(sectioned.count == repository.catalog.allergens.count)
    }

    @Test("Allergen ids are unique")
    func idsAreUnique() throws {
        let repository = try AllergenRepository(loader: loader)
        let ids = repository.catalog.allergens.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    @Test("No keyword survives indexing with a parenthetical annotation")
    func annotationsWereSplitOut() throws {
        let repository = try AllergenRepository(loader: loader)

        // Entries such as "鸡蛋 (Chinese)" could never match a real label.
        let annotated = repository.keywordIndex.entries.filter {
            $0.term.text.contains("(") || $0.term.text.contains(")")
        }

        #expect(annotated.isEmpty)
    }

    @Test("Themes, onboarding copy and configuration load")
    func auxiliaryResourcesLoad() throws {
        let themes = try loader.load(ThemeCollection.self, named: "Themes")
        let onboarding = try loader.load(OnboardingContent.self, named: "OnboardingContent")
        let configuration = try loader.load(AppConfiguration.self, named: "AppConfiguration")

        #expect(themes.defaultTheme != nil)
        #expect(themes.themes.count == 21)
        #expect(onboarding.acknowledgementPageIndex != nil)
        #expect(!onboarding.pages.isEmpty)
        #expect(configuration.allergenRequestForm != nil)
    }

    @Test("A realistic label is scored end to end")
    func endToEndScan() throws {
        let repository = try AllergenRepository(loader: loader)
        let label = """
        INGREDIENTS: Wheat flour, sugar, palm oil, cocoa butter, whole milk powder, \
        soy lecithin (E322), salt.
        May contain traces of peanuts and tree nuts.
        """

        let result = repository.detector.result(
            for: label,
            avoiding: [AllergenID("dairy"), AllergenID("peanut")]
        )

        let bySeverity = Dictionary(
            uniqueKeysWithValues: result.detections.map { ($0.allergen.id, $0.severity) }
        )

        #expect(bySeverity[AllergenID("dairy")] == .avoid)
        #expect(bySeverity[AllergenID("peanut")] == .advisory)
        // Wheat is on the label but is not one of this user's allergens.
        #expect(bySeverity[AllergenID("wheat")] == .informational)
    }
}

@Suite("Allergen profile")
@MainActor
struct AllergenProfileTests {

    @Test("Selections round-trip through UserDefaults")
    func persistence() {
        let (defaults, suiteName) = Fixtures.isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let profile = AllergenProfile(defaults: defaults)
        profile.setEnabled(true, for: AllergenID("peanut"))
        profile.setEnabled(true, for: AllergenID("dairy"))
        profile.setEnabled(false, for: AllergenID("dairy"))

        let reloaded = AllergenProfile(defaults: defaults)

        #expect(reloaded.enabledIDs == [AllergenID("peanut")])
        #expect(reloaded.isEnabled(AllergenID("peanut")))
        #expect(!reloaded.isEnabled(AllergenID("dairy")))
    }

    @Test("Toggling flips a single allergen")
    func toggling() {
        let (defaults, suiteName) = Fixtures.isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let profile = AllergenProfile(defaults: defaults)
        let egg = AllergenID("egg")

        profile.toggle(egg)
        #expect(profile.isEnabled(egg))

        profile.toggle(egg)
        #expect(!profile.isEnabled(egg))
    }

    @Test("A SafeEats 1.1 selection is migrated to the new format")
    func legacyMigration() throws {
        let (defaults, suiteName) = Fixtures.isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // The shape written by the previous release.
        let legacy = Data("""
        [
          {"id": "peanut", "name": "Peanut", "isEnabled": true, "showForThreeSeconds": false},
          {"id": "dairy", "name": "Dairy", "isEnabled": false, "showForThreeSeconds": false},
          {"id": "sesame", "name": "Sesame", "isEnabled": true, "showForThreeSeconds": false}
        ]
        """.utf8)
        defaults.set(legacy, forKey: "selectedAllergens")

        let profile = AllergenProfile(defaults: defaults)

        #expect(profile.enabledIDs == [AllergenID("peanut"), AllergenID("sesame")])
        // The migration is written back, so it only runs once.
        #expect(defaults.stringArray(forKey: "enabledAllergenIDs") == ["peanut", "sesame"])
    }

    @Test("Unreadable legacy data starts empty instead of crashing")
    func corruptLegacyData() {
        let (defaults, suiteName) = Fixtures.isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(Data("not json".utf8), forKey: "selectedAllergens")

        #expect(AllergenProfile(defaults: defaults).enabledIDs.isEmpty)
    }
}
