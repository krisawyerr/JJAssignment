//
//  CameraPreviewView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import AVFoundation
import CoreData
 
struct CameraPreviewView: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        controller.setPreviewView(view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    var backPreviewLayer: AVCaptureVideoPreviewLayer?

    func setupPreviewLayers(with session: AVCaptureMultiCamSession) {
        cleanupPreviewLayers()

        frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)

        frontPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.videoGravity = .resizeAspectFill

        setupConnections(for: session)

        if let frontLayer = frontPreviewLayer {
            layer.addSublayer(frontLayer)
        }
        if let backLayer = backPreviewLayer {
            layer.addSublayer(backLayer)
        }

        setNeedsLayout()
    }

    private func setupConnections(for session: AVCaptureMultiCamSession) {
        let inputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }

        for input in inputs {
            let videoPort = input.ports(for: .video, sourceDeviceType: input.device.deviceType, sourceDevicePosition: input.device.position).first

            if let port = videoPort {
                let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: (input.device.position == .front ? frontPreviewLayer : backPreviewLayer)!)

                if session.canAddConnection(connection) {
                    session.addConnection(connection)
                }
            }
        }
    }

    func cleanupPreviewLayers() {
        frontPreviewLayer?.removeFromSuperlayer()
        backPreviewLayer?.removeFromSuperlayer()
        frontPreviewLayer = nil
        backPreviewLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let halfHeight = bounds.height / 2
        frontPreviewLayer?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfHeight)
        backPreviewLayer?.frame = CGRect(x: 0, y: halfHeight, width: bounds.width, height: halfHeight)
    }
}
