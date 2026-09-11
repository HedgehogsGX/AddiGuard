import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onRotationAngleChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onRotationAngleChange = onRotationAngleChange
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.onRotationAngleChange = onRotationAngleChange
        uiView.updateVideoRotation()
    }
}

final class PreviewView: UIView {
    var onRotationAngleChange: ((CGFloat) -> Void)?
    private var appliedRotationAngle: CGFloat?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateVideoRotation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateVideoRotation()
    }

    func updateVideoRotation() {
        guard let orientation = window?.windowScene?.interfaceOrientation else { return }
        let angle = orientation.videoRotationAngle
        guard appliedRotationAngle != angle else { return }
        appliedRotationAngle = angle
        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        onRotationAngleChange?(angle)
    }
}

private extension UIInterfaceOrientation {
    var videoRotationAngle: CGFloat {
        switch self {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeLeft: 180
        case .landscapeRight: 0
        default: 90
        }
    }
}
