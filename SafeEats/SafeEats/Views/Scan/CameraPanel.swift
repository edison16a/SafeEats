//
//  CameraPanel.swift
//  SafeEats
//

import AVFoundation
import SwiftUI

/// The live preview, or an explanation of why there isn't one.
///
/// Permission and failure states get the same space the preview would, so the
/// layout doesn't jump around when the camera can't start.
struct CameraPanel: View {
    let state: ScanModel.CameraState
    let session: AVCaptureSession

    var body: some View {
        ZStack {
            switch state {
            case .running:
                CameraPreview(session: session)

            case .idle, .starting:
                message(
                    symbol: "camera",
                    title: "Starting the camera…",
                    detail: nil
                )

            case .denied:
                message(
                    symbol: "camera.badge.ellipsis",
                    title: "Camera access is off",
                    detail: "Turn on camera access for SafeEats in Settings to scan labels."
                )

            case .failed(let reason):
                message(
                    symbol: "exclamationmark.triangle",
                    title: "The camera could not start",
                    detail: reason
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

    private func message(symbol: String, title: String, detail: String?) -> some View {
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
}
