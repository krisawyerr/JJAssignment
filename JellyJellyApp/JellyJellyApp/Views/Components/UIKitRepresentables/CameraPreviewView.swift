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
    var backgroundSampleBufferLayer: AVSampleBufferDisplayLayer?
    private var blurEffectView: UIVisualEffectView?
    private var frontScrollGesture: UIPanGestureRecognizer?
    private var backScrollGesture: UIPanGestureRecognizer?
    private weak var cameraController: CameraController?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var frontGridLayer: CAShapeLayer?
    private var backGridLayer: CAShapeLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        setupBackgroundLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = true
        setupBackgroundLayer()
    }

    private func setupBackgroundLayer() {
        backgroundSampleBufferLayer = AVSampleBufferDisplayLayer()
        backgroundSampleBufferLayer?.videoGravity = .resizeAspectFill
        backgroundSampleBufferLayer?.frame = bounds
        
        let rotationTransform = CGAffineTransform(rotationAngle: .pi / 2)
        let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
        let combinedTransform = rotationTransform.concatenating(flipTransform)
        backgroundSampleBufferLayer?.setAffineTransform(combinedTransform)
        
        if let backgroundLayer = backgroundSampleBufferLayer {
            layer.addSublayer(backgroundLayer)
        }
        
        setupBlurEffect()
    }
    
    private func setupBlurEffect() {
        let blurEffect = UIBlurEffect(style: .light) 
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView?.frame = bounds
        blurEffectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if let blurView = blurEffectView {
            addSubview(blurView)
        }
    }

    private func setupGridLayers() {
        frontGridLayer = CAShapeLayer()
        frontGridLayer?.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        frontGridLayer?.lineWidth = 1.0
        frontGridLayer?.fillColor = nil
        
        backGridLayer = CAShapeLayer()
        backGridLayer?.strokeColor = UIColor.white.withAlphaComponent(0.5).cgColor
        backGridLayer?.lineWidth = 1.0
        backGridLayer?.fillColor = nil
    }

    private func updateGridLayers() {
        guard let frontGridLayer = frontGridLayer,
              let backGridLayer = backGridLayer,
              let frontPreviewLayer = frontPreviewLayer,
              let backPreviewLayer = backPreviewLayer else { return }
        
        let frontPath = UIBezierPath()
        let frontHeight = frontPreviewLayer.frame.height
        let quarterHeight = frontHeight / 4
        
        frontPath.move(to: CGPoint(x: 0, y: quarterHeight))
        frontPath.addLine(to: CGPoint(x: frontPreviewLayer.frame.width, y: quarterHeight))
        
        frontPath.move(to: CGPoint(x: 0, y: frontHeight - quarterHeight))
        frontPath.addLine(to: CGPoint(x: frontPreviewLayer.frame.width, y: frontHeight - quarterHeight))
        
        frontGridLayer.path = frontPath.cgPath
        
        let backPath = UIBezierPath()
        let backHeight = backPreviewLayer.frame.height
        let backQuarterHeight = backHeight / 4
        
        backPath.move(to: CGPoint(x: 0, y: backQuarterHeight))
        backPath.addLine(to: CGPoint(x: backPreviewLayer.frame.width, y: backQuarterHeight))
        
        backPath.move(to: CGPoint(x: 0, y: backHeight - backQuarterHeight))
        backPath.addLine(to: CGPoint(x: backPreviewLayer.frame.width, y: backHeight - backQuarterHeight))
        
        backGridLayer.path = backPath.cgPath
    }

    func setupPreviewLayers(with session: AVCaptureMultiCamSession) {
        cleanupPreviewLayers()
        setupBackgroundLayer()
        setupGridLayers()

        frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)

        frontPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.videoGravity = .resizeAspectFill

        setupConnections(for: session)
        setupVideoDataOutput(for: session)

        if let frontLayer = frontPreviewLayer {
            layer.addSublayer(frontLayer)
            if let frontGridLayer = frontGridLayer {
                frontLayer.addSublayer(frontGridLayer)
            }
            setupPinchGesture(for: .front)
        }
        if let backLayer = backPreviewLayer {
            layer.addSublayer(backLayer)
            if let backGridLayer = backGridLayer {
                backLayer.addSublayer(backGridLayer)
            }
            setupPinchGesture(for: .back)
        }

        setNeedsLayout()
    }

    private func setupVideoDataOutput(for session: AVCaptureMultiCamSession) {
        guard let backCameraInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput })
            .first(where: { $0.device.position == .back }) else {
            return
        }

        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput?.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

        if session.canAddOutput(videoDataOutput!) {
            session.addOutput(videoDataOutput!)
            
            if let videoPort = backCameraInput.ports(for: .video, sourceDeviceType: backCameraInput.device.deviceType, sourceDevicePosition: .back).first {
                let videoConnection = AVCaptureConnection(inputPorts: [videoPort], output: videoDataOutput!)
                
                if session.canAddConnection(videoConnection) {
                    session.addConnection(videoConnection)
                    
                    if videoConnection.isVideoOrientationSupported {
                        videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait
                    }
                    if videoConnection.isVideoStabilizationSupported {
                        videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
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
        let position: AVCaptureDevice.Position = location.x < bounds.width / 2 ? .front : .back
        
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
        backgroundSampleBufferLayer?.removeFromSuperlayer()
        frontPreviewLayer?.removeFromSuperlayer()
        backPreviewLayer?.removeFromSuperlayer()
        blurEffectView?.removeFromSuperview()
        
        if let output = videoDataOutput {
            if let session = frontPreviewLayer?.session {
                session.removeOutput(output)
            }
        }
        
        backgroundSampleBufferLayer = nil
        frontPreviewLayer = nil
        backPreviewLayer = nil
        videoDataOutput = nil
        blurEffectView = nil
        frontGridLayer = nil
        backGridLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundSampleBufferLayer?.frame = bounds
        let rotationTransform = CGAffineTransform(rotationAngle: .pi / 2)
        let flipTransform = CGAffineTransform(scaleX: -1, y: 1)
        let combinedTransform = rotationTransform.concatenating(flipTransform)
        backgroundSampleBufferLayer?.setAffineTransform(combinedTransform)
        
        blurEffectView?.frame = bounds
        
        if let cameraController = cameraController {
            let halfWidth = bounds.width / 2
            
            let aspectRatio: CGFloat = 9.0 / 16.0
            let videoHeight = halfWidth / aspectRatio
            
            let yOffset = (bounds.height - videoHeight) / 2
            
            frontPreviewLayer?.frame = CGRect(x: 0, y: yOffset, width: halfWidth, height: videoHeight)
            backPreviewLayer?.frame = CGRect(x: halfWidth, y: yOffset, width: halfWidth, height: videoHeight)
            
            frontGridLayer?.frame = frontPreviewLayer?.bounds ?? .zero
            backGridLayer?.frame = backPreviewLayer?.bounds ?? .zero
            
            updateGridLayers()
        }
    }
}

extension CameraPreviewUIView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        backgroundSampleBufferLayer?.enqueue(sampleBuffer)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped sample buffer")
    }
}

extension CameraPreviewUIView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
