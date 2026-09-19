//
//  CameraPreview.swift
//  SafeEats
//

import AVFoundation
import SwiftUI
import UIKit

/// A `UIView` whose backing layer *is* the capture preview layer.
///
/// Using `layerClass` lets UIKit resize the preview automatically. The previous
/// implementation added a sublayer and then copied `view.bounds` into its frame
/// from both `viewDidLoad` and `viewDidLayoutSubviews`, which had to be kept in
/// sync by hand and still lagged a rotation by a frame.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Safe: `layerClass` above guarantees the type.
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("layerClass must be AVCaptureVideoPreviewLayer")
        }
        return layer
    }
}

/// Shows the live camera feed for a capture session.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}
