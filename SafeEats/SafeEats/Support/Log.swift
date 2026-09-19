//
//  Log.swift
//  SafeEats
//

import Foundation
import OSLog

/// Subsystem-scoped loggers, so Console can be filtered per concern.
///
/// Replaces the scattered `print(…)` calls, which were invisible on a device
/// and shipped straight into release builds.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Safe.SafeEats"

    /// Loading and decoding of bundled JSON resources.
    static let resources = Logger(subsystem: subsystem, category: "resources")
    /// Camera authorization, configuration and session lifecycle.
    static let camera = Logger(subsystem: subsystem, category: "camera")
    /// Text recognition and allergen matching.
    static let scanning = Logger(subsystem: subsystem, category: "scanning")
}
