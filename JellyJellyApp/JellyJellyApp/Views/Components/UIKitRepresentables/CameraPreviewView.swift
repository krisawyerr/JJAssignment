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
    let cameraLayoutMode: CameraController.CameraLayoutMode

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        controller.setPreviewView(view)
        view.setCameraController(controller)
        view.cameraLayoutMode = cameraLayoutMode
        if controller.session.isRunning {
            DispatchQueue.main.async {
                view.setupPreviewLayers(with: controller.session)
                controller.isPreviewReady = true
            }
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        controller.setPreviewView(uiView)
        if uiView.cameraLayoutMode != cameraLayoutMode {
            uiView.setLayoutMode(cameraLayoutMode: cameraLayoutMode)
        }
    }
}

class CameraPreviewUIView: UIView {
    var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    var backPreviewLayer: AVCaptureVideoPreviewLayer?
    // var backgroundSampleBufferLayer: AVSampleBufferDisplayLayer?
    // private var blurEffectView: UIVisualEffectView?
    private var frontScrollGesture: UIPanGestureRecognizer?
    private var backScrollGesture: UIPanGestureRecognizer?
    private weak var cameraController: CameraController?
    var cameraLayoutMode: CameraController.CameraLayoutMode = .topBottom
    var activeCameraInFrontOnlyMode: AVCaptureDevice.Position = .front

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        // setupBackgroundLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = true
        // setupBackgroundLayer()
    }

    // private func setupBackgroundLayer() {
    //     backgroundSampleBufferLayer = AVSampleBufferDisplayLayer()
    //     backgroundSampleBufferLayer?.videoGravity = .resizeAspectFill
    //     backgroundSampleBufferLayer?.frame = bounds
        
    //     let rotationTransform = CGAffineTransform(rotationAngle: .pi / 2)
    //     let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
    //     let combinedTransform = rotationTransform.concatenating(flipTransform)
    //     backgroundSampleBufferLayer?.setAffineTransform(combinedTransform)
        
    //     if let backgroundLayer = backgroundSampleBufferLayer {
    //         layer.addSublayer(backgroundLayer)
    //     }
        
    //     setupBlurEffect()
    // }
    
    // private func setupBlurEffect() {
    //     let blurEffect = UIBlurEffect(style: .light) 
    //     blurEffectView = UIVisualEffectView(effect: blurEffect)
    //     blurEffectView?.frame = bounds
    //     blurEffectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
    //     if let blurView = blurEffectView {
    //         addSubview(blurView)
    //     }
    // }

    func setupPreviewLayers(with session: AVCaptureMultiCamSession) {
        cleanupPreviewLayers()

        frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)

        frontPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.videoGravity = .resizeAspectFill

        if let frontLayer = frontPreviewLayer {
            layer.addSublayer(frontLayer)
            setupPinchGesture(for: .front)
        }
        if let backLayer = backPreviewLayer {
            layer.addSublayer(backLayer)
            setupPinchGesture(for: .back)
        }

        setupConnections(for: session)

        setNeedsLayout()
        layoutIfNeeded()
    }

    private func setupConnections(for session: AVCaptureMultiCamSession) {
        let inputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }

        for input in inputs {
            let videoPort = input.ports(for: .video, sourceDeviceType: input.device.deviceType, sourceDevicePosition: input.device.position).first

            if let port = videoPort {
                let previewLayer = input.device.position == .front ? frontPreviewLayer : backPreviewLayer
                if let layer = previewLayer {
                    let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
                    
                    if session.canAddConnection(connection) {
                        session.addConnection(connection)
                    }
                }
            }
        }
    }

    private func setupPinchGesture(for position: AVCaptureDevice.Position) {
        let scrollGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScroll(_:)))
        scrollGesture.delegate = self
        addGestureRecognizer(scrollGesture)
        
        if position == .front {
            frontScrollGesture = scrollGesture
        } else {
            backScrollGesture = scrollGesture
        }
    }

    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        guard let cameraController = cameraController else { return }
        
        let location = gesture.location(in: self)
        let position: AVCaptureDevice.Position
        
        if cameraLayoutMode == .frontOnly {
            position = activeCameraInFrontOnlyMode
        } else if cameraLayoutMode == .topBottom {
            position = location.y < bounds.height / 2 ? .front : .back
        } else {
            position = location.x < bounds.width / 2 ? .front : .back
        }
        
        let translation = gesture.translation(in: self)
        let zoomDelta = -translation.y / 100.0 
        
        switch gesture.state {
        case .changed:
            let currentZoom = position == .front ? cameraController.frontZoomFactor : cameraController.backZoomFactor
            let newZoom = currentZoom + zoomDelta
            cameraController.setZoomFactor(newZoom, forCamera: position)
            gesture.setTranslation(.zero, in: self)
        default:
            break
        }
    }

    func setCameraController(_ controller: CameraController) {
        self.cameraController = controller
    }

    func cleanupPreviewLayers() {
        frontPreviewLayer?.removeFromSuperlayer()
        backPreviewLayer?.removeFromSuperlayer()
        
        frontPreviewLayer = nil
        backPreviewLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let rotationTransform = CGAffineTransform(rotationAngle: .pi / 2)
        let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
        let combinedTransform = rotationTransform.concatenating(flipTransform)
        
        if let _ = cameraController,
           let frontLayer = frontPreviewLayer,
           let backLayer = backPreviewLayer {
            let aspectRatio: CGFloat = 9.0 / 16.0
            
            if cameraLayoutMode == .frontOnly {
                if activeCameraInFrontOnlyMode == .front {
                    frontLayer.frame = bounds
                    backLayer.isHidden = true
                    frontLayer.isHidden = false
                } else {
                    backLayer.frame = bounds
                    frontLayer.isHidden = true
                    backLayer.isHidden = false
                }
            } else if cameraLayoutMode == .topBottom {
                let videoWidth = bounds.width
                let videoHeight = bounds.height
                let halfHeight = videoHeight / 2
                
                let xOffset = (bounds.width - videoWidth) / 2
                let topYOffset = 0 
                let bottomYOffset = halfHeight
                
                frontLayer.frame = CGRect(x: xOffset, y: CGFloat(topYOffset), width: videoWidth, height: halfHeight)
                backLayer.frame = CGRect(x: xOffset, y: bottomYOffset, width: videoWidth, height: halfHeight)
                
                frontLayer.isHidden = false
                backLayer.isHidden = false
            } else {
                let halfWidth = bounds.width / 2
                let videoHeight = halfWidth / aspectRatio
                let yOffset = (bounds.height - videoHeight) / 2
                
                frontLayer.frame = CGRect(x: 0, y: yOffset, width: halfWidth, height: videoHeight)
                backLayer.frame = CGRect(x: halfWidth, y: yOffset, width: halfWidth, height: videoHeight)
                
                frontLayer.isHidden = false
                backLayer.isHidden = false
            }
        }
    }

    func setLayoutMode(cameraLayoutMode: CameraController.CameraLayoutMode) {
        print("Setting layout mode to: \(cameraLayoutMode == .frontOnly ? "front-only" : (cameraLayoutMode == .topBottom ? "top-bottom" : "side-by-side"))")
        self.cameraLayoutMode = cameraLayoutMode
        
        if cameraLayoutMode == .frontOnly {
            activeCameraInFrontOnlyMode = .front
        }
        
        if let frontLayer = frontPreviewLayer,
           let backLayer = backPreviewLayer {
            if cameraLayoutMode == .frontOnly {
                if activeCameraInFrontOnlyMode == .front {
                    frontLayer.isHidden = false
                    backLayer.isHidden = true
                } else {
                    frontLayer.isHidden = true
                    backLayer.isHidden = false
                }
            } else {
                frontLayer.isHidden = false
                backLayer.isHidden = false
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.setNeedsLayout()
            self?.layoutIfNeeded()
        }
    }
    
    func flipCameraInFrontOnlyMode() {
        guard cameraLayoutMode == .frontOnly else { return }
        
        activeCameraInFrontOnlyMode = activeCameraInFrontOnlyMode == .front ? .back : .front
        print("Switched to \(activeCameraInFrontOnlyMode == .front ? "front" : "back") camera in front-only mode")
        
        cameraController?.recordCameraSwitch()
        
        setNeedsLayout()
        layoutIfNeeded()
    }
}

extension CameraPreviewUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
