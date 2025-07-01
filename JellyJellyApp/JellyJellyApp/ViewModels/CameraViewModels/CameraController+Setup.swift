import AVFoundation
import Foundation
import SwiftUI

extension CameraController {
    func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isSessionSetup && self.session.isRunning { return }
            if self.previewView == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.setupCamera()
                }
                return
            }
            if self.isSessionSetup {
                self.resetSession()
            }
            guard AVCaptureMultiCamSession.isMultiCamSupported else {
                print("MultiCam not supported")
                return
            }
            self.preWarmCameraDevices()
            self.setupInputsWithNoConnections()
            self.setupAllOutputs()
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.previewView?.setupPreviewLayers(with: self.session)
                self.isPreviewReady = true
                self.frontVideoDataOutput?.setSampleBufferDelegate(self, queue: self.sessionQueue)
                self.backVideoDataOutput?.setSampleBufferDelegate(self, queue: self.sessionQueue)
                self.applyInitialZoomSettings()
                DispatchQueue.global(qos: .utility).async {
                    self.preWarmWriter()
                }
            }
            self.isSessionSetup = true
        }
    }
    private func setupInputsWithNoConnections() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        do {
            if let front = getBestFrontCamera() {
                let frontDeviceInput = try AVCaptureDeviceInput(device: front)
                self.frontCamera = front
                self.frontInput = frontDeviceInput
                if self.session.canAddInput(frontDeviceInput) {
                    self.session.addInputWithNoConnections(frontDeviceInput)
                } else {
                    print("Failed to add front camera input")
                }
            } else {
                print("No front camera available")
            }
            if let back = getBestBackCamera() {
                let backDeviceInput = try AVCaptureDeviceInput(device: back)
                self.backCamera = back
                self.backInput = backDeviceInput
                if self.session.canAddInput(backDeviceInput) {
                    self.session.addInputWithNoConnections(backDeviceInput)
                } else {
                    print("Failed to add back camera input")
                }
            } else {
                print("No back camera available")
            }
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if self.session.canAddInput(audioInput) {
                    self.session.addInputWithNoConnections(audioInput)
                } else {
                    print("Failed to add audio input")
                }
            } else {
                print("No audio device available")
            }
        } catch {
            print("Camera setup error: \(error)")
        }
    }
    private func setupAllOutputs() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if self.session.canAddOutput(self.frontOutput) {
            self.session.addOutputWithNoConnections(self.frontOutput)
        }
        if self.session.canAddOutput(self.backOutput) {
            self.session.addOutputWithNoConnections(self.backOutput)
        }
        configureAudioOutputs()
        configureVideoDataOutputs()
    }
    private func configureAudioOutputs() {
        if self.session.canAddOutput(self.frontAudioOutput) {
            self.session.addOutputWithNoConnections(self.frontAudioOutput)
            self.frontAudioOutput.setSampleBufferDelegate(self, queue: self.audioOutQueue)
        } else {
            print("Failed to add front audio output")
        }
        if let audioInput = session.inputs.first(where: { $0 is AVCaptureDeviceInput && ($0 as! AVCaptureDeviceInput).device.hasMediaType(.audio) }) as? AVCaptureDeviceInput {
            if let audioPort = audioInput.ports(for: .audio, sourceDeviceType: audioInput.device.deviceType, sourceDevicePosition: .unspecified).first {
                let frontAudioConnection = AVCaptureConnection(inputPorts: [audioPort], output: self.frontAudioOutput)
                if session.canAddConnection(frontAudioConnection) {
                    session.addConnection(frontAudioConnection)
                } else {
                    print("Failed to add front audio connection")
                }
            }
        }
    }
    private func configureVideoDataOutputs() {
        if let frontInput = frontInput {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            output.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(output) {
                session.addOutputWithNoConnections(output)
                if let port = frontInput.ports(for: .video, sourceDeviceType: frontInput.device.deviceType, sourceDevicePosition: .front).first {
                    let connection = AVCaptureConnection(inputPorts: [port], output: output)
                    if session.canAddConnection(connection) {
                        session.addConnection(connection)
                    }
                }
            }
            frontVideoDataOutput = output
            if let videoPort = frontInput.ports(for: .video, sourceDeviceType: frontInput.device.deviceType, sourceDevicePosition: .front).first {
                let frontVideoConnection = AVCaptureConnection(inputPorts: [videoPort], output: self.frontOutput)
                if session.canAddConnection(frontVideoConnection) {
                    session.addConnection(frontVideoConnection)
                } else {
                    print("Failed to add front video connection to movie output")
                }
            }
        }
        if let backInput = backInput {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            output.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(output) {
                session.addOutputWithNoConnections(output)
                if let port = backInput.ports(for: .video, sourceDeviceType: backInput.device.deviceType, sourceDevicePosition: .back).first {
                    let connection = AVCaptureConnection(inputPorts: [port], output: output)
                    if session.canAddConnection(connection) {
                        session.addConnection(connection)
                    }
                }
            }
            backVideoDataOutput = output
            if let videoPort = backInput.ports(for: .video, sourceDeviceType: backInput.device.deviceType, sourceDevicePosition: .back).first {
                let backVideoConnection = AVCaptureConnection(inputPorts: [videoPort], output: self.backOutput)
                if session.canAddConnection(backVideoConnection) {
                    session.addConnection(backVideoConnection)
                } else {
                    print("Failed to add back video connection to movie output")
                }
            }
        }
    }
    private func resetSession() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.resetSession() }
            return
        }
        stopTimer()
        isPreviewReady = false
        if isRecording {
            frontOutput.stopRecording()
            backOutput.stopRecording()
            isRecording = false
        }
        recordingCompletionCount = 0
        previewView?.cleanupPreviewLayers()
        session.beginConfiguration()
        session.inputs.forEach { input in
            session.removeInput(input)
        }
        session.outputs.forEach { output in
            session.removeOutput(output)
        }
        session.commitConfiguration()
        isSessionSetup = false
        secondsRemaining = maxRecordingTime
    }
    func stopCamera() {
        previewView?.cleanupPreviewLayers()
        stopTimer()
        if isRecording {
            frontOutput.stopRecording()
            backOutput.stopRecording()
            isRecording = false
        }
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.session.beginConfiguration()
                self.session.commitConfiguration()
                self.session.stopRunning()
            }
        }
    }
    func pauseCamera() {
        guard session.isRunning && !isPaused else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isPaused = true
                print("Camera paused")
            }
        }
    }
    func resumeCamera() {
        guard !session.isRunning && isPaused else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isPaused = false
                print("Camera resumed")
            }
        }
    }
    private func preWarmCameraDevices() {
        if let front = getBestFrontCamera() {
            do {
                try front.lockForConfiguration()
                front.unlockForConfiguration()
            } catch {
                print("Failed to pre-warm front camera: \(error)")
            }
        }
        if let back = getBestBackCamera() {
            do {
                try back.lockForConfiguration()
                back.unlockForConfiguration()
            } catch {
                print("Failed to pre-warm back camera: \(error)")
            }
        }
    }
    private func getBestFrontCamera() -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }
    private func getBestBackCamera() -> AVCaptureDevice? {
        if let ultraWideCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            backCameraType = .builtInUltraWideCamera
            backInitialZoom = currentBackZoom.zoomFactor
            print("Using ultra-wide camera with initial zoom: \(currentBackZoom.displayText)")
            return ultraWideCamera
        }
        if let wideCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCameraType = .builtInWideAngleCamera
            backInitialZoom = currentBackZoom.zoomFactor
            print("Using wide-angle camera with initial zoom: \(currentBackZoom.displayText)")
            return wideCamera
        }
        print("No back camera available")
        return nil
    }
    func getCurrentBackCameraType() -> AVCaptureDevice.DeviceType? {
        return backCameraType
    }
    func isUsingUltraWideCamera() -> Bool {
        return backCameraType == .builtInUltraWideCamera
    }
} 