//
//  TextRecognitionService.swift
//  SafeEats
//

import Foundation
import Vision
import CoreVideo
import ImageIO
import OSLog

/// Reads text out of a camera frame with the Vision framework.
///
/// Immutable and free of shared mutable state — a fresh `VNRecognizeTextRequest`
/// is created per call — so it is safe to use from the capture queue.
final class TextRecognitionService: Sendable {
    enum RecognitionError: LocalizedError {
        case requestFailed(any Error)

        var errorDescription: String? {
            switch self {
            case .requestFailed(let underlying):
                return "Could not read the label: \(underlying.localizedDescription)"
            }
        }
    }

    /// Languages we would like Vision to recognise, in priority order.
    ///
    /// These mirror the languages the keyword vocabularies cover. The previous
    /// implementation left this unset, so Vision only ever looked for English
    /// and the Chinese, Japanese, Dutch, German and Spanish keyword lists could
    /// never match anything.
    private static let preferredLanguages = [
        "en-US", "es-ES", "de-DE", "nl-NL", "zh-Hans", "ja-JP"
    ]

    private let recognitionLanguages: [String]

    init() {
        self.recognitionLanguages = Self.resolveSupportedLanguages()
    }

    /// Recognises the text in a camera frame.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Frame to read. Only valid for the duration of the call,
    ///     so this method runs Vision synchronously rather than retaining it.
    ///   - orientation: Orientation of `pixelBuffer`. Callers that rotate the
    ///     capture connection to portrait should pass `.up`.
    /// - Returns: The recognised lines joined by newlines. Line structure is
    ///   preserved because ``AdvisoryMatcher`` uses it to tell a `Contains:`
    ///   line apart from a `May contain:` line.
    func recognizeText(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = recognitionLanguages
        // Language correction helps far more than it hurts on printed labels,
        // where the recogniser is mostly reading ordinary words.
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            Log.scanning.error("Vision request failed: \(error.localizedDescription, privacy: .public)")
            throw RecognitionError.requestFailed(error)
        }

        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Narrows ``preferredLanguages`` to those the installed Vision revision supports.
    private static func resolveSupportedLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate

        guard let supported = try? request.supportedRecognitionLanguages() else {
            Log.scanning.warning("Could not query Vision languages; falling back to English.")
            return ["en-US"]
        }

        let available = preferredLanguages.filter(supported.contains)
        return available.isEmpty ? ["en-US"] : available
    }
}
