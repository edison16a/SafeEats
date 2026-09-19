//
//  TextMatchingTests.swift
//  SafeEatsTests
//

import Foundation
import Testing
@testable import SafeEats

@Suite("Text folding")
struct TextFoldingTests {

    @Test("Latin folding removes case and diacritics")
    func latinFolding() {
        let text = ScannedLabelText("Maíz y Leche Entera")
        #expect(text.latinFolded == "maiz y leche entera")
    }

    @Test("Unicode folding keeps Japanese voiced marks intact")
    func kanaFoldingKeepsDakuten() {
        // Stripping diacritics here would turn バター (butter) into ハター.
        let text = ScannedLabelText("バター")
        #expect(text.unicodeFolded.contains("バター"))
    }

    @Test("Runs of spaces collapse but line breaks survive")
    func whitespaceCollapsing() {
        let text = ScannedLabelText("contains:    milk\nmay contain:  soy")
        #expect(text.latinFolded == "contains: milk\nmay contain: soy")
    }

    @Test("Scripts are classified by their characters")
    func scriptClassification() {
        #expect(TermScript.classify("peanut butter") == .segmented)
        #expect(TermScript.classify("Erdnussöl") == .segmented)
        #expect(TermScript.classify("牛奶") == .unsegmented)
        #expect(TermScript.classify("ピーナッツ") == .unsegmented)
    }
}

@Suite("Boundary-aware matching")
struct StringMatchingTests {

    @Test("A leading boundary stops matches inside longer words")
    func leadingBoundaryRejectsInfixes() {
        // The old plain `contains` check flagged meat on "graham flour",
        // because "ham" is a meat keyword.
        #expect(!"graham flour".containsMatch(of: "ham", boundary: .leading))
        #expect("smoked ham".containsMatch(of: "ham", boundary: .leading))
    }

    @Test("A leading boundary still allows useful prefixes")
    func leadingBoundaryAllowsSuffixedWords() {
        // "cornstarch" really is corn, and plurals must keep matching.
        #expect("modified cornstarch".containsMatch(of: "corn", boundary: .leading))
        #expect("roasted peanuts".containsMatch(of: "peanut", boundary: .leading))
    }

    @Test("Additive codes need a boundary on both sides")
    func additiveCodesAreFullyDelimited() {
        #expect("emulsifier e322".containsMatch(of: "e322", boundary: .leadingAndTrailing))
        #expect(!"emulsifier e3220".containsMatch(of: "e322", boundary: .leadingAndTrailing))
    }

    @Test("Unsegmented scripts match as plain substrings")
    func unsegmentedMatching() {
        #expect("原材料:牛奶、砂糖".containsMatch(of: "牛奶", boundary: .none))
    }

    @Test("Every occurrence is reported")
    func allOccurrences() {
        let ranges = "milk, dark milk, white milk".matchRanges(of: "milk", boundary: .leading)
        #expect(ranges.count == 3)
    }

    @Test("An empty needle never matches")
    func emptyNeedle() {
        #expect("anything".matchRanges(of: "", boundary: .leading).isEmpty)
    }
}
