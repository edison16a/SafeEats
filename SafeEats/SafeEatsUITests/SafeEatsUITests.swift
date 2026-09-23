//
//  SafeEatsUITests.swift
//  SafeEatsUITests
//
//  Created by Edison Law on 11/13/24.
//

import XCTest

final class SafeEatsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Smoke test: the app launches and stays up.
    ///
    /// Deliberately asserts on the process state rather than on any particular
    /// button or label. SafeEats decides between onboarding and the main tabs
    /// based on saved state, so a test that looks for specific views would
    /// depend on which screen the simulator happens to start on. This catches
    /// the failure that actually matters here, which is a missing or malformed
    /// bundled resource taking the app down at launch.
    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
