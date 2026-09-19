//
//  ScanScreen.swift
//  SafeEats
//

import SwiftUI

/// The Scan tab: live camera, a scan button, and the results of the last scan.
struct ScanScreen: View {
    let model: ScanModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                cameraPanel
                scanButton
                resultsPanel
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        // Starting in `.task` and stopping in `.onDisappear` keeps the session
        // tied to the tab's lifetime; the old view controller stopped the
        // session on disappear and never restarted it.
        .task { await model.startCamera() }
        .onDisappear { model.stopCamera() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 4) {
            Text("Scan")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Point and hold the camera at a food label.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Label("Always double-check the packaging yourself.", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var cameraPanel: some View {
        ZStack {
            switch model.cameraState {
            case .running:
                CameraPreview(session: model.captureSession)

            case .idle, .starting:
                cameraMessage(
                    symbol: "camera",
                    title: "Starting the camera…",
                    detail: nil
                )

            case .denied:
                cameraMessage(
                    symbol: "camera.badge.ellipsis",
                    title: "Camera access is off",
                    detail: "Turn on camera access for SafeEats in Settings to scan labels."
                )

            case .failed(let message):
                cameraMessage(
                    symbol: "exclamationmark.triangle",
                    title: "The camera could not start",
                    detail: message
                )
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("Camera preview")
    }

    private func cameraMessage(symbol: String, title: String, detail: String?) -> some View {
        ZStack {
            Color.black.opacity(0.65)

            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 30))
                Text(title)
                    .font(.headline)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(20)
        }
    }

    private var scanButton: some View {
        Button {
            model.scan()
        } label: {
            HStack(spacing: 8) {
                if model.isScanning {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "text.viewfinder")
                }
                Text(model.isScanning ? "Reading label…" : "Scan Now")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isScanEnabled ? Color.accentColor : Color.gray)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isScanEnabled)
        .accessibilityHint("Reads the label currently in the camera preview.")
    }

    private var isScanEnabled: Bool {
        model.cameraState == .running && !model.isScanning
    }

    @ViewBuilder
    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Allergens Detected")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if model.hasScanned {
                    Button("Clear") { model.clearResult() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            if !model.hasScanned {
                emptyState(
                    "Nothing scanned yet",
                    detail: "Tap Scan Now with a label in view."
                )
            } else if model.result.isEmpty {
                emptyState(
                    "No text was read",
                    detail: "Try moving closer, steadying the camera, or improving the lighting."
                )
            } else if model.result.detections.isEmpty {
                emptyState(
                    "No known allergens found",
                    detail: "SafeEats did not recognise any of its keywords on this label. Check the packaging yourself."
                )
            } else {
                DetectionGrid(detections: model.result.detections)
                legend
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelBackground()
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([DetectionSeverity.avoid, .advisory, .informational], id: \.self) { severity in
                HStack(spacing: 5) {
                    Circle()
                        .fill(severity.tint)
                        .frame(width: 9, height: 9)
                    Text(severity.title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }
}
