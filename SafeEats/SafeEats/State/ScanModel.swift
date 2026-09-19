//
//  ScanModel.swift
//  SafeEats
//

import AVFoundation
import CoreVideo
import Foundation
import Observation
import OSLog

/// Drives the Scan tab: owns the camera, turns a captured frame into text, and
/// turns that text into allergen detections.
///
/// The expensive part of a scan (Vision text recognition) runs on the capture
/// queue; only the finished string comes back to the main actor, where the
/// detector runs against the user's current profile. Reading the profile at the
/// end rather than capturing it up front means toggling an allergen mid-scan
/// still produces the right answer.
@MainActor
@Observable
final class ScanModel {
    /// What the camera is doing, so the UI can explain itself.
    enum CameraState: Equatable {
        case idle
        case starting
        case running
        case denied
        case failed(String)
    }

    private(set) var cameraState: CameraState = .idle
    /// The most recent scan, or ``ScanResult/none`` before the first one.
    private(set) var result: ScanResult = .none
    /// True between tapping Scan and the result arriving.
    private(set) var isScanning = false
    /// True once at least one scan has completed.
    private(set) var hasScanned = false

    /// The capture session the preview layer renders.
    var captureSession: AVCaptureSession { camera.session }

    @ObservationIgnored
    private let camera: CameraSession
    @ObservationIgnored
    private let recognizer: TextRecognitionService
    @ObservationIgnored
    private let detector: AllergenDetector
    @ObservationIgnored
    private let profile: AllergenProfile
    @ObservationIgnored
    private var scanTimeoutTask: Task<Void, Never>?

    /// How long to wait for a frame before giving up on a scan.
    private static let scanTimeout: Duration = .seconds(5)

    init(
        detector: AllergenDetector,
        profile: AllergenProfile,
        recognizer: TextRecognitionService = TextRecognitionService(),
        camera: CameraSession = CameraSession()
    ) {
        self.detector = detector
        self.profile = profile
        self.recognizer = recognizer
        self.camera = camera

        camera.onFrameCaptured = makeFrameHandler()
    }

    // MARK: - Camera lifecycle

    /// Starts the camera. Safe to call every time the Scan tab appears.
    func startCamera() async {
        guard cameraState != .running, cameraState != .starting else { return }
        cameraState = .starting

        do {
            try await camera.start()
            cameraState = .running
        } catch CameraSession.CameraError.accessDenied {
            cameraState = .denied
        } catch {
            cameraState = .failed(error.localizedDescription)
        }
    }

    /// Stops the camera when the Scan tab goes away, so it is not left running
    /// in the background burning battery.
    func stopCamera() {
        camera.stop()
        cancelScanTimeout()
        isScanning = false
        if cameraState == .running || cameraState == .starting {
            cameraState = .idle
        }
    }

    // MARK: - Scanning

    /// Arms the next camera frame for recognition.
    func scan() {
        guard cameraState == .running, !isScanning else { return }
        isScanning = true
        camera.requestSingleFrame()
        startScanTimeout()
    }

    /// Releases the scan button if no frame ever arrives, rather than leaving
    /// the UI stuck in "Reading label…" indefinitely.
    private func startScanTimeout() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.scanTimeout)
            guard !Task.isCancelled else { return }
            self?.abandonScan()
        }
    }

    private func cancelScanTimeout() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
    }

    private func abandonScan() {
        guard isScanning else { return }
        isScanning = false
        Log.scanning.warning("Scan timed out before a camera frame arrived.")
    }

    /// Clears the previous result, e.g. before pointing at a different product.
    func clearResult() {
        result = .none
        hasScanned = false
    }

    /// Builds the closure the capture queue calls with a frame.
    ///
    /// The recogniser is captured directly — it is `Sendable` and immutable —
    /// while `self` is only touched back on the main actor.
    private func makeFrameHandler() -> CameraSession.FrameHandler {
        { [recognizer, weak self] pixelBuffer in
            // Runs on the capture queue. The buffer is recycled the moment this
            // returns, so recognition has to happen here and now.
            let text = (try? recognizer.recognizeText(in: pixelBuffer)) ?? ""

            Task { @MainActor in
                self?.finishScan(with: text)
            }
        }
    }

    private func finishScan(with text: String) {
        cancelScanTimeout()
        result = detector.result(for: text, avoiding: profile.enabledIDs)
        isScanning = false
        hasScanned = true

        Log.scanning.info(
            "Scan read \(text.count) characters and matched \(self.result.detections.count) allergens."
        )
    }

    /// Re-runs detection on the last scan, for when the user changes their
    /// allergen selection and comes back to the results.
    func reevaluateLastScan() {
        guard hasScanned, !result.recognizedText.isEmpty else { return }
        result = detector.result(for: result.recognizedText, avoiding: profile.enabledIDs)
    }
}
