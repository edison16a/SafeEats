//
//  CameraSession.swift
//  SafeEats
//

import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import OSLog

/// Owns the `AVCaptureSession` and hands out a single frame when asked.
///
/// Scanning is deliberately on demand: the session streams continuously so the
/// preview stays live, but frames are dropped on the floor until
/// ``requestSingleFrame()`` arms the next one. Running text recognition on every
/// frame would heat the device for no benefit. Someone photographing an
/// ingredient list wants one careful read, not thirty per second.
///
/// - Note: Marked `@unchecked Sendable` because its mutable state is protected
///   manually: ``session`` is only reconfigured on ``sessionQueue``, and the
///   scan-request flag is guarded by ``scanRequestLock``.
final class CameraSession: NSObject, @unchecked Sendable {
    /// Called on the capture queue with a frame that must be processed synchronously.
    ///
    /// The buffer belongs to the capture pipeline and is recycled as soon as
    /// this returns, so handlers must not store it.
    typealias FrameHandler = @Sendable (CVPixelBuffer) -> Void

    enum CameraError: LocalizedError {
        case accessDenied
        case cameraUnavailable
        case configurationFailed(any Error)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "SafeEats needs camera access to read food labels. You can grant it in Settings."
            case .cameraUnavailable:
                return "No camera is available on this device."
            case .configurationFailed(let underlying):
                return "The camera could not be started: \(underlying.localizedDescription)"
            }
        }
    }

    /// The session backing the preview layer.
    let session = AVCaptureSession()

    /// Set before calling ``start()``. Invoked on the capture queue.
    var onFrameCaptured: FrameHandler?

    private let sessionQueue = DispatchQueue(label: "com.safeeats.camera.session")
    private let outputQueue = DispatchQueue(label: "com.safeeats.camera.output")
    private let output = AVCaptureVideoDataOutput()

    /// Guarded by ``sessionQueue``.
    private var isConfigured = false

    private let scanRequestLock = NSLock()
    /// Guarded by ``scanRequestLock``.
    private var isFrameRequested = false

    /// Asks for camera permission, configuring nothing.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Configures the session if needed and starts it.
    ///
    /// Safe to call every time the Scan tab appears: configuration happens once
    /// and starting an already-running session is a no-op. The old view
    /// controller stopped the session in `viewDidDisappear` and never started it
    /// again, so the preview went black for good after the first tab switch.
    func start() async throws {
        guard await Self.requestAccess() else {
            throw CameraError.accessDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            sessionQueue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning {
                        // Blocking call, which is why it is not on the main thread.
                        self.session.startRunning()
                    }
                    continuation.resume()
                } catch {
                    Log.camera.error("Camera start failed: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Stops the session and discards any pending scan request.
    func stop() {
        clearFrameRequest()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Arms the next frame for delivery to ``onFrameCaptured``.
    func requestSingleFrame() {
        scanRequestLock.withLock { isFrameRequested = true }
    }

    private func clearFrameRequest() {
        scanRequestLock.withLock { isFrameRequested = false }
    }

    /// Consumes the pending request, returning whether one was armed.
    private func consumeFrameRequest() -> Bool {
        scanRequestLock.withLock { () -> Bool in
            defer { isFrameRequested = false }
            return isFrameRequested
        }
    }

    // MARK: - Configuration

    /// - Precondition: Runs on ``sessionQueue``.
    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        guard let device = Self.preferredCaptureDevice() else {
            throw CameraError.cameraUnavailable
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 1280×720 is ample for reading print and keeps each Vision pass cheap.
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw CameraError.cameraUnavailable
            }
            session.addInput(input)
        } catch let error as CameraError {
            throw error
        } catch {
            throw CameraError.configurationFailed(error)
        }

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: outputQueue)

        guard session.canAddOutput(output) else {
            throw CameraError.cameraUnavailable
        }
        session.addOutput(output)

        // Rotate in the capture pipeline so Vision receives an upright frame.
        // The old code passed `.up` for a buffer that was actually landscape,
        // which left the recogniser reading sideways text.
        if let connection = output.connection(with: .video),
           connection.isVideoRotationAngleSupported(Self.portraitRotationAngle) {
            connection.videoRotationAngle = Self.portraitRotationAngle
        }

        isConfigured = true
    }

    /// Degrees of rotation that turn a back-camera frame upright in portrait.
    private static let portraitRotationAngle: CGFloat = 90

    private static func preferredCaptureDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard consumeFrameRequest(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        onFrameCaptured?(pixelBuffer)
    }
}
