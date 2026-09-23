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

                CameraPanel(
                    state: model.cameraState,
                    session: model.captureSession
                )

                scanButton

                ScanResultsPanel(
                    result: model.result,
                    hasScanned: model.hasScanned,
                    onClear: { model.clearResult() }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        // Starting in `.task` and stopping in `.onDisappear` ties the session to
        // the tab's lifetime. The old view controller stopped the session on
        // disappear and never restarted it.
        .task { await model.startCamera() }
        .onDisappear { model.stopCamera() }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Scan")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Point and hold the camera at a food label.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Label(
                "Always double-check the packaging yourself.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.yellow)
            .multilineTextAlignment(.center)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
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
}
