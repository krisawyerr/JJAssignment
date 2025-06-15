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
        view.setCameraController(controller)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontPinchGesture: UIPinchGestureRecognizer?
    private var backPinchGesture: UIPinchGestureRecognizer?
    private weak var cameraController: CameraController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = true
    }

    func setupPreviewLayers(with session: AVCaptureMultiCamSession) {
        cleanupPreviewLayers()

        frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)

        frontPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.videoGravity = .resizeAspectFill

        setupConnections(for: session)

        if let frontLayer = frontPreviewLayer {
            layer.addSublayer(frontLayer)
            setupPinchGesture(for: .front)
        }
        if let backLayer = backPreviewLayer {
            layer.addSublayer(backLayer)
            setupPinchGesture(for: .back)
        }

        setNeedsLayout()
    }

    private func setupPinchGesture(for position: AVCaptureDevice.Position) {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)
        
        if position == .front {
            frontPinchGesture = pinchGesture
        } else {
            backPinchGesture = pinchGesture
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let cameraController = cameraController else { return }
        
        let location = gesture.location(in: self)
        let position: AVCaptureDevice.Position = location.y < bounds.height / 2 ? .front : .back
        
        cameraController.handlePinchGesture(gesture, forCamera: position)
    }

    func setCameraController(_ controller: CameraController) {
        self.cameraController = controller
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

extension CameraPreviewUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
