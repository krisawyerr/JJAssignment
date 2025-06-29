//
//  CameraController.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

import SwiftUI
import AVFoundation
import CoreData
import FirebaseStorage
import CoreImage
import Foundation
import UIKit

class BlurVideoCompositor: NSObject, AVVideoCompositing {
    nonisolated var sourcePixelBufferAttributes: [String : Any]? {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    
    nonisolated var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    
    private var context: CIContext?
    private var blurFilter: CIFilter?
    
    override init() {
        super.init()
        context = CIContext()
        blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(5.0, forKey: kCIInputRadiusKey)
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        context = CIContext()
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: kCMPersistentTrackID_Invalid) else {
            if let blackPixelBuffer = createBlackPixelBuffer(size: asyncVideoCompositionRequest.renderContext.size) {
                asyncVideoCompositionRequest.finish(withComposedVideoFrame: blackPixelBuffer)
            } else {
                if let originalPixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: kCMPersistentTrackID_Invalid) {
                    asyncVideoCompositionRequest.finish(withComposedVideoFrame: originalPixelBuffer)
                }
            }
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: sourcePixelBuffer)
        blurFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = blurFilter?.outputImage,
              let context = context,
              let outputPixelBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: sourcePixelBuffer)
            return
        }
        
        context.render(outputImage, to: outputPixelBuffer)
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputPixelBuffer)
    }
    
    private func createBlackPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(size.width),
                                       Int(size.height),
                                       kCVPixelFormatType_32BGRA,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        return pixelBuffer
    }
}

class CameraController: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureMultiCamSession()
    private let frontOutput = AVCaptureMovieFileOutput()
    private let backOutput = AVCaptureMovieFileOutput()
    private let storage = Storage.storage()
    private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
    
    private let frontAudioOutput = AVCaptureAudioDataOutput()
    private let audioOutQueue = DispatchQueue(label: "com.jellyjelly.CameraController.audioDataOutputQueue")
    
    private weak var previewView: CameraPreviewUIView?
    private var frontURL: URL?
    private var backURL: URL?
    @Published var mergedVideoURL: URL?
    @Published var isRecording = false
    @Published var secondsRemaining = 15000
    @Published var isPreviewReady = false
    @Published var immediatePreviewURL: URL?
    @Published var frontPreviewURL: URL?
    @Published var backPreviewURL: URL?
    @Published var frontZoomFactor: CGFloat = 1.0
    @Published var backZoomFactor: CGFloat = 1.0
    @Published var isPaused = false
    @Published var isFlashOn = false
    
    private var isTorchActive = false
    
    var isFlashAvailable: Bool {
        guard let backCamera = backCamera else { return false }
        return backCamera.isTorchModeSupported(.on)
    }
    
    enum CameraLayoutMode: CaseIterable {
        case topBottom
        case sideBySide
        case frontOnly
        
        var icon: String {
            switch self {
            case .topBottom:
                return "rectangle.split.1x2"
            case .sideBySide:
                return "rectangle.split.2x1"
            case .frontOnly:
                return "rectangle"
            }
        }
        
        var next: CameraLayoutMode {
            switch self {
            case .topBottom:
                return .sideBySide
            case .sideBySide:
                return .frontOnly
            case .frontOnly:
                return .topBottom
            }
        }
    }
    
    @Published var cameraLayoutMode: CameraLayoutMode = .topBottom
    
    enum BackCameraZoom: CaseIterable {
        case oneX
        case twoX
        // case threeX
        
        var zoomFactor: CGFloat {
            switch self {
            case .oneX: return 1.0
            case .twoX: return 2.0
            // case .threeX: return 4.0
            }
        }
        
        var displayText: String {
            switch self {
            case .oneX: return "0.5x"
            case .twoX: return "1x"
            // case .threeX: return "2x"
            }
        }
        
        var next: BackCameraZoom {
            switch self {
            case .oneX: return .twoX
            case .twoX: return .oneX
            // case .threeX: return .oneX
            }
        }
    }
    
    @Published var currentBackZoom: BackCameraZoom = .twoX
    @Published var activeCameraInFrontOnlyMode: AVCaptureDevice.Position = .front
    @Published var exactBackZoomFactor: CGFloat = 2.0
    
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontInput: AVCaptureDeviceInput?
    private var backInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var isSessionSetup = false
    private var frontInitialZoom: CGFloat = 1.0
    private var backInitialZoom: CGFloat = 1.0
    
    private var recordingTimer: Timer?
    private let maxRecordingTime = 15000
    
    private var recordingCompletionCount = 0
    private var storedContext: NSManagedObjectContext?
    private var processingStartTime: CFAbsoluteTime = 0
    private var lastRecordedVideo: RecordedVideo?
    var cameraSwitchTimestamps: [CFAbsoluteTime] = []
    private var recordingStartTime: CFAbsoluteTime = 0
    var initialCameraPosition: AVCaptureDevice.Position = .front
    
    var onVideoProcessed: (() -> Void)?
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var ciContext = CIContext()
    private var frameCount: Int64 = 0
    private var startTime: CMTime?
    private var outputURL: URL?
    private var frontFrameBuffer: [CMTime: CMSampleBuffer] = [:]
    private var backFrameBuffer: [CMTime: CMSampleBuffer] = [:]
    private var lastFrontTime: CMTime?
    private var lastBackTime: CMTime?
    private var isWriterReady: Bool = false
    private var isAudioReady = false
    private var audioSessionStarted = false
    private let writerSessionLock = NSLock()
    private var audioInputWriter: AVAssetWriterInput?
    private var hasPreWarmedWriter = false
    private let frameBufferLock = NSLock()
    private var frontVideoDataOutput: AVCaptureVideoDataOutput?
    private var backVideoDataOutput: AVCaptureVideoDataOutput?
    
    private var backCameraType: AVCaptureDevice.DeviceType?
    
    @Published var frontAudioLevel: CGFloat = 0.0
    private var audioLevelTimer: Timer?
    
    
    private func configureAudioSessionForFrontCameraRecording() throws {
        let session = AVAudioSession.sharedInstance()
        
        try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true, options: [.notifyOthersOnDeactivation])
        
        guard let micInput = session.availableInputs?.first(where: {
            $0.portType == AVAudioSession.Port.builtInMic
        }) else {
            return
        }
        
        if let bottomSource = micInput.dataSources?.first(where: {
            $0.orientation == AVAudioSession.Orientation.bottom
        }) {
            try micInput.setPreferredDataSource(bottomSource)
        } else {
            print("Bottom mic data source not found, using default")
        }
        
        try session.setPreferredInput(micInput)
    }
    
    private func deactivateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
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
    
    func preWarmWriter() {
        guard !hasPreWarmedWriter else { return }
        hasPreWarmedWriter = true
        let tempDir = FileManager.default.temporaryDirectory
        let dummyURL = tempDir.appendingPathComponent("prewarm_dummy.mp4")
        try? FileManager.default.removeItem(at: dummyURL)
        outputURL = dummyURL
        setupWriter()
        assetWriter?.cancelWriting()
        assetWriter = nil
        videoInput = nil
        audioInputWriter = nil
        pixelBufferAdaptor = nil
        outputURL = nil
        isWriterReady = false
    }
    
    func setPreviewView(_ view: CameraPreviewUIView) {
        self.previewView = view
        setupCamera()
    }
    
    func resetPreviewState() {
        frontURL = nil
        backURL = nil
        mergedVideoURL = nil
        frontPreviewURL = nil
        backPreviewURL = nil
        immediatePreviewURL = nil
        
        isRecording = false
        secondsRemaining = maxRecordingTime
        recordingCompletionCount = 0

        if session.isRunning, let previewView = previewView {
            DispatchQueue.main.async {
                previewView.setupPreviewLayers(with: self.session)
                self.isPreviewReady = true
                self.applyInitialZoomSettings()
                self.preWarmWriter()
            }
        }
    }
    
    func clearMergedVideo() {
        let mergedURLToDelete = mergedVideoURL
        mergedVideoURL = nil
        
        if let context = storedContext, let mergedURL = mergedURLToDelete {
            let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedURL.absoluteString)
            
            if let video = try? context.fetch(fetchRequest).first {
                context.delete(video)
                try? context.save()
            }
        }
        
        if let mergedURL = mergedURLToDelete {
            try? FileManager.default.removeItem(at: mergedURL)
        }
    }
    
    func retakeVideo() {
        let frontURLToDelete = frontURL
        let backURLToDelete = backURL
        let mergedURLToDelete = mergedVideoURL
        let contextToUse = storedContext
        
        frontURL = nil
        backURL = nil
        mergedVideoURL = nil
        frontPreviewURL = nil
        backPreviewURL = nil
        immediatePreviewURL = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let context = contextToUse {
                let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                
                if let mergedURL = mergedURLToDelete {
                    let videoURL = mergedURL.absoluteString
                    fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", videoURL)
                } else {
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)]
                    fetchRequest.fetchLimit = 1
                }
                
                if let video = try? context.fetch(fetchRequest).first {
                    self.lastRecordedVideo = video
                    
                    Task {
                        do {
                            try await self.deleteVideoFromFirebase(video: video)
                        } catch {
                            print("Error deleting video from Firebase: \(error.localizedDescription)")
                        }
                    }
                    
                    context.delete(video)
                    try? context.save()
                }
            }
            
            if let frontURL = frontURLToDelete {
                try? FileManager.default.removeItem(at: frontURL)
            }
            if let backURL = backURLToDelete {
                try? FileManager.default.removeItem(at: backURL)
            }
            if let mergedURL = mergedURLToDelete {
                try? FileManager.default.removeItem(at: mergedURL)
            }
        }
        
        do {
            try deactivateAudioSession()
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    func undoRecording() {
        if isRecording {
            frontOutput.stopRecording()
            backOutput.stopRecording()
            isRecording = false
        }
        
        if let frontURL = frontURL {
            try? FileManager.default.removeItem(at: frontURL)
        }
        if let backURL = backURL {
            try? FileManager.default.removeItem(at: backURL)
        }
        
        frontURL = nil
        backURL = nil
        frontPreviewURL = nil
        backPreviewURL = nil
        
        secondsRemaining = maxRecordingTime
        recordingCompletionCount = 0
        
        stopTimer()
    }
    
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
                do {
                    self.session.beginConfiguration()
                    self.session.commitConfiguration()
                    self.session.stopRunning()
                } catch {
                    print("Error stopping camera session: \(error.localizedDescription)")
                }
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
    
    func startRecording(context: NSManagedObjectContext) {
        guard !isRecording else {
            return
        }
        
        cleanupWriter()
        
        do {
            try configureAudioSessionForFrontCameraRecording()
        } catch {
            print("Failed to configure audio session for front camera recording: \(error)")
        }
        
        storedContext = context
        recordingCompletionCount = 0
        secondsRemaining = maxRecordingTime
        cameraSwitchTimestamps.removeAll()
        recordingStartTime = CFAbsoluteTimeGetCurrent()
        if cameraLayoutMode == .frontOnly {
            initialCameraPosition = activeCameraInFrontOnlyMode
        } else {
            initialCameraPosition = .front
        }
        let timestamp = Date().timeIntervalSince1970
        let tempDir = FileManager.default.temporaryDirectory
        outputURL = tempDir.appendingPathComponent("merged_realtime_\(timestamp).mp4")
        setupWriter()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
        startTimer()
    }
    
    func stopRecording() {
        guard isRecording else {
            return
        }
        stopTimer()
        finishWriter()
        
        do {
            try deactivateAudioSession()
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func cleanupWriter() {
        if let assetWriter = assetWriter, assetWriter.status == .writing {
            assetWriter.cancelWriting()
        }
        
        videoInput = nil
        audioInputWriter = nil
        pixelBufferAdaptor = nil
        assetWriter = nil
        isWriterReady = false
        isAudioReady = false
        audioSessionStarted = false
        frameCount = 0
        startTime = nil
        
        frameBufferLock.lock()
        frontFrameBuffer.removeAll()
        backFrameBuffer.removeAll()
        frameBufferLock.unlock()
        
        if let outputURL = outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
    }
    
    private func setupWriter() {
        guard let outputURL = outputURL else { return }
        
        cleanupWriter()
        
        let size = CGSize(width: 720, height: 1280)
        assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        guard let assetWriter = assetWriter else {
            print("Failed to create AVAssetWriter")
            return
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        if let videoInput = videoInput, assetWriter.canAdd(videoInput) {
            assetWriter.add(videoInput)
        } else {
            print("Failed to add video input to asset writer")
            return
        }
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 48000,
            AVEncoderBitRateKey: 128000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let audioInputWriter = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInputWriter.expectsMediaDataInRealTime = true
        if assetWriter.canAdd(audioInputWriter) {
            assetWriter.add(audioInputWriter)
            self.audioInputWriter = audioInputWriter
        } else {
            print("Failed to add audio input to asset writer")
            return
        }
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: nil)
        
        if assetWriter.status == .unknown {
            assetWriter.startWriting()
            frameCount = 0
            startTime = nil
            isWriterReady = true
            isAudioReady = true
            audioSessionStarted = false
        } else {
            print("AssetWriter status is not unknown: \(assetWriter.status.rawValue)")
            cleanupWriter()
        }
    }
    
    private func finishWriter() {
        guard let assetWriter = assetWriter, assetWriter.status == .writing else {
            print("AssetWriter is not in writing state, cleaning up")
            cleanupWriter()
            return
        }
        
        videoInput?.markAsFinished()
        audioInputWriter?.markAsFinished()
        
        assetWriter.finishWriting { [weak self] in
            guard let self = self, let outputURL = self.outputURL else {
                self?.cleanupWriter()
                return
            }
            
            DispatchQueue.main.async {
                let fileManager = FileManager.default
                if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let destURL = documentsURL.appendingPathComponent(outputURL.lastPathComponent)
                    try? fileManager.removeItem(at: destURL)
                    do {
                        try fileManager.moveItem(at: outputURL, to: destURL)
                        if let context = self.storedContext {
                            let newRecording = RecordedVideo(context: context)
                            newRecording.createdAt = Date()
                            newRecording.mergedVideoURL = destURL.absoluteString
                            newRecording.isSideBySide = (self.cameraLayoutMode == .sideBySide)
                            newRecording.isFrontOnly = (self.cameraLayoutMode == .frontOnly)
                            try? context.save()
                            
                            self.createWatermarkedVersion(originalURL: destURL, context: context, video: newRecording)
                        }
                        self.mergedVideoURL = destURL
                    } catch {
                        print("Failed to move merged video to Documents: \(error)")
                        if let context = self.storedContext {
                            let newRecording = RecordedVideo(context: context)
                            newRecording.createdAt = Date()
                            newRecording.mergedVideoURL = outputURL.absoluteString
                            newRecording.isSideBySide = (self.cameraLayoutMode == .sideBySide)
                            newRecording.isFrontOnly = (self.cameraLayoutMode == .frontOnly)
                            try? context.save()
                            
                            self.createWatermarkedVersion(originalURL: outputURL, context: context, video: newRecording)
                        }
                        self.mergedVideoURL = outputURL
                    }
                    self.onVideoProcessed?()
                }
                
                self.cleanupWriter()
            }
        }
        
        isWriterReady = false
    }
    
    private func createWatermarkedVersion(originalURL: URL, context: NSManagedObjectContext, video: RecordedVideo) {
        let watermarkedFileName = "watermarked_\(originalURL.lastPathComponent)"
        let watermarkedURL = originalURL.deletingLastPathComponent().appendingPathComponent(watermarkedFileName)
        
        DispatchQueue.global(qos: .userInitiated).async {
            VideoWatermarkService.shared.addWatermarkToVideo(inputURL: originalURL, outputURL: watermarkedURL) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let watermarkedURL):
                        video.watermarkedVideoURL = watermarkedURL.absoluteString
                        try? context.save()
                        print("Watermarked video created successfully: \(watermarkedURL)")
                    case .failure(let error):
                        print("Failed to create watermarked video: \(error)")
                    }
                }
            }
        }
    }
    
    func processFrontSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isWriterReady else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        frameBufferLock.lock()
        frontFrameBuffer[time] = sampleBuffer
        lastFrontTime = time
        frameBufferLock.unlock()
        tryToMergeFrame(at: time)
    }
    
    func processBackSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isWriterReady else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        frameBufferLock.lock()
        backFrameBuffer[time] = sampleBuffer
        lastBackTime = time
        frameBufferLock.unlock()
        tryToMergeFrame(at: time)
    }
    
    private func tryToMergeFrame(at time: CMTime) {
        frameBufferLock.lock()
        guard let frontTime = lastFrontTime, let backTime = lastBackTime else { frameBufferLock.unlock(); return }
        let tolerance = CMTime(value: 1, timescale: 30)
        if abs(frontTime.seconds - backTime.seconds) < tolerance.seconds {
            guard let frontBuffer = frontFrameBuffer[frontTime], let backBuffer = backFrameBuffer[backTime] else { frameBufferLock.unlock(); return }
            writerSessionLock.lock()
            if startTime == nil {
                assetWriter?.startSession(atSourceTime: frontTime)
                startTime = frontTime
            }
            writerSessionLock.unlock()
            compositeAndWrite(frontBuffer: frontBuffer, backBuffer: backBuffer, at: frontTime)
            frontFrameBuffer.removeValue(forKey: frontTime)
            backFrameBuffer.removeValue(forKey: backTime)
        }
        frameBufferLock.unlock()
    }
    
    private func compositeAndWrite(frontBuffer: CMSampleBuffer, backBuffer: CMSampleBuffer, at time: CMTime) {
        guard let assetWriter = assetWriter, let videoInput = videoInput, let pixelBufferAdaptor = pixelBufferAdaptor, videoInput.isReadyForMoreMediaData else { return }
        guard let frontPixelBuffer = CMSampleBufferGetImageBuffer(frontBuffer), let backPixelBuffer = CMSampleBufferGetImageBuffer(backBuffer) else { return }
        
        if assetWriter.status == .unknown {
            assetWriter.startSession(atSourceTime: time)
            startTime = time
        }
        
        let frontImageRaw = CIImage(cvPixelBuffer: frontPixelBuffer)
        let backImageRaw = CIImage(cvPixelBuffer: backPixelBuffer)
        let frontRotate = CGAffineTransform(translationX: 0, y: frontImageRaw.extent.width).rotated(by: -.pi / 2)
        let backRotate = CGAffineTransform(translationX: 0, y: backImageRaw.extent.width).rotated(by: -.pi / 2)
        let frontImage = frontImageRaw.transformed(by: frontRotate)
        let mirror = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -frontImage.extent.width, y: 0)
        let frontImageMirrored = frontImage.transformed(by: mirror)
        let backImage = backImageRaw.transformed(by: backRotate)
        let size = CGSize(width: 720, height: 1280)
        var outputImage: CIImage
        switch cameraLayoutMode {
        case .sideBySide:
            let halfWidth = size.width / 2

            let frontScale = min(halfWidth / frontImageMirrored.extent.width, size.height / frontImageMirrored.extent.height)
            let frontScaled = frontImageMirrored.transformed(by: .init(scaleX: frontScale, y: frontScale))
            let frontX = (halfWidth - frontScaled.extent.width) / 2
            let frontY = (size.height - frontScaled.extent.height) / 2

            let frontMoved = frontScaled.transformed(by: .init(translationX: frontX, y: frontY))
            let backScale = min(halfWidth / backImage.extent.width, size.height / backImage.extent.height)
            let backScaled = backImage.transformed(by: .init(scaleX: backScale, y: backScale))
            let backX = halfWidth + (halfWidth - backScaled.extent.width) / 2
            let backY = (size.height - backScaled.extent.height) / 2
            let backMoved = backScaled.transformed(by: .init(translationX: backX, y: backY))
            outputImage = frontMoved.composited(over: backMoved)
        case .topBottom:
            let halfHeight = size.height / 2
            let frontCropRect = CGRect(x: 0, y: frontImageMirrored.extent.height / 4, width: frontImageMirrored.extent.width, height: frontImageMirrored.extent.height / 2)
            let backCropRect = CGRect(x: 0, y: backImage.extent.height / 4, width: backImage.extent.width, height: backImage.extent.height / 2)
            let frontCropped = frontImageMirrored.cropped(to: frontCropRect)
            let backCropped = backImage.cropped(to: backCropRect)

            let frontResized = frontCropped.transformed(by: .init(scaleX: size.width / frontCropped.extent.width, y: halfHeight / frontCropped.extent.height))
            let backResized = backCropped.transformed(by: .init(scaleX: size.width / backCropped.extent.width, y: halfHeight / backCropped.extent.height))
            let frontMoved = frontResized.transformed(by: .init(translationX: 0, y: halfHeight / 2))
            let backMoved = backResized.transformed(by: .init(translationX: 0, y: -halfHeight / 2))
            outputImage = backMoved.composited(over: frontMoved)
        case .frontOnly:
            let currentTime = time.seconds - (startTime?.seconds ?? 0)
            var showFront = initialCameraPosition == .front
            for switchTime in cameraSwitchTimestamps {
                if currentTime >= switchTime {
                    showFront.toggle()
                } else {
                    break
                }
            }
            let chosenImage = showFront ? frontImageMirrored : backImage
            outputImage = chosenImage.transformed(by: .init(scaleX: size.width / chosenImage.extent.width, y: size.height / chosenImage.extent.height))
        }
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            ciContext.render(outputImage, to: pixelBuffer)
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: time)
            frameCount += 1
        }
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.secondsRemaining -= 10
                
                if self.secondsRemaining <= 0 {
                    self.stopRecording()
                }
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func setZoomFactor(_ factor: CGFloat, forCamera position: AVCaptureDevice.Position) {
         guard let device = position == .front ? frontCamera : backCamera else { return }
        
         do {
             try device.lockForConfiguration()
             let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 42.0)
             let clampedFactor = min(max(factor, 1.0), maxZoom)
            
             if position == .front {
                 frontZoomFactor = clampedFactor
                 device.videoZoomFactor = clampedFactor
             } else {
                 backZoomFactor = clampedFactor
                 device.videoZoomFactor = clampedFactor
                 exactBackZoomFactor = clampedFactor
                 
                 if clampedFactor <= 1.0 {
                     currentBackZoom = .oneX
                 } else {
                     currentBackZoom = .twoX
                //  } else {
                //      currentBackZoom = .threeX
                 }
             }
            
             device.unlockForConfiguration()
         } catch {
             print("Error setting zoom factor: \(error.localizedDescription)")
         }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
        
        if isRecording {
            if isFlashOn {
                turnFlashOff()
            } else {
                turnFlashOn()
            }
        }
    }
    
    func turnFlashOn() {
        guard let backCamera = backCamera else { return }
        
        do {
            try backCamera.lockForConfiguration()
            
            if backCamera.isTorchModeSupported(.on) {
                backCamera.torchMode = .on
                isTorchActive = true
            }
            
            backCamera.unlockForConfiguration()
        } catch {
            print("Error turning flash on: \(error.localizedDescription)")
        }
    }
    
    func turnFlashOff() {
        guard let backCamera = backCamera else { return }
        
        do {
            try backCamera.lockForConfiguration()
            
            if backCamera.isTorchModeSupported(.off) {
                backCamera.torchMode = .off
                isTorchActive = false
            }
            
            backCamera.unlockForConfiguration()
        } catch {
            print("Error turning flash off: \(error.localizedDescription)")
        }
    }
    
    func uploadVideoToFirebase(video: RecordedVideo, context: NSManagedObjectContext) async throws {
        guard let mergedVideoURL = video.mergedVideoURL,
              let videoURL = URL(string: mergedVideoURL) else {
            throw NSError(domain: "VideoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        let timestamp = Date().timeIntervalSince1970
        let storageRef = storage.reference().child("videos/\(timestamp).mp4")
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = try await storageRef.putFileAsync(from: videoURL, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        await MainActor.run {
            video.firebaseStorageURL = downloadURL.absoluteString
            try? context.save()
        }
    }
    
    func deleteVideoFromFirebase(video: RecordedVideo) async throws {
        guard let firebaseURL = video.firebaseStorageURL else {
            return
        }
        
        let storageRef = storage.reference(forURL: firebaseURL)
        try await storageRef.delete()
    }
    
    func recordCameraSwitch() {
        if isRecording {
            let switchTime = CFAbsoluteTimeGetCurrent() - recordingStartTime
            cameraSwitchTimestamps.append(switchTime)
            print("Camera switch recorded at: \(switchTime)s")
        }
    }
    
    func flipCameraInFrontOnlyMode() {
        print("flipCameraInFrontOnlyMode called - current mode: \(cameraLayoutMode), current active camera: \(activeCameraInFrontOnlyMode)")
        
        if isRecording && isFlashOn {
            if getCurrentActiveCameraPosition() == .front {
                turnFlashOn()
            } else {
                turnFlashOff()
            }
        }
        
        let previousCamera = activeCameraInFrontOnlyMode
        activeCameraInFrontOnlyMode = activeCameraInFrontOnlyMode == .front ? .back : .front
        
        if isRecording {
            recordCameraSwitch()
        }
        
        previewView?.flipCameraInFrontOnlyMode()
    }
    
    func getCurrentActiveCameraPosition() -> AVCaptureDevice.Position {
        if cameraLayoutMode == .frontOnly {
            return activeCameraInFrontOnlyMode
        } else {
            return .back
        }
    }
    
    private func applyInitialZoomSettings() {
        if let frontCamera = frontCamera {
            do {
                try frontCamera.lockForConfiguration()
                frontCamera.videoZoomFactor = frontInitialZoom
                frontZoomFactor = frontInitialZoom
                frontCamera.unlockForConfiguration()
            } catch {
                print("Failed to set front camera initial zoom: \(error)")
            }
        }
        
        if let backCamera = backCamera {
            do {
                try backCamera.lockForConfiguration()
                backCamera.videoZoomFactor = backInitialZoom
                backZoomFactor = backInitialZoom
                exactBackZoomFactor = backInitialZoom
                backCamera.unlockForConfiguration()
            } catch {
                print("Failed to set back camera initial zoom: \(error)")
            }
        }
    }
    
    func getCurrentBackCameraType() -> AVCaptureDevice.DeviceType? {
        return backCameraType
    }
    
    func isUsingUltraWideCamera() -> Bool {
        return backCameraType == .builtInUltraWideCamera
    }
    
    func cycleBackCameraZoom() {
        guard let backCamera = backCamera else { return }
        
        let maxZoom = backCamera.activeFormat.videoMaxZoomFactor
        
        var nextZoom = currentBackZoom.next
        while nextZoom.zoomFactor > maxZoom && nextZoom != currentBackZoom {
            nextZoom = nextZoom.next
        }
        
        currentBackZoom = nextZoom
        exactBackZoomFactor = currentBackZoom.zoomFactor
        setZoomFactor(currentBackZoom.zoomFactor, forCamera: .back)
        print("Back camera zoom changed to: \(currentBackZoom.displayText)")
    }
    
    func getMaxBackCameraZoom() -> CGFloat {
        guard let backCamera = backCamera else { return 1.0 }
        return min(backCamera.activeFormat.videoMaxZoomFactor, 42.0)
    }
    
    func getBackZoomDisplayText() -> String {
        let tolerance: CGFloat = 0.1
        if abs(exactBackZoomFactor - currentBackZoom.zoomFactor) < tolerance {
            return currentBackZoom.displayText
        } else {
            return String(format: "%.1fx", exactBackZoomFactor / 2)
        }
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {

        recordingCompletionCount += 1

        if let error = error {
            print("Recording error: \(error.localizedDescription)")
        }

        if recordingCompletionCount >= 2 {
            DispatchQueue.main.async {
                if let frontURL = self.frontURL, let backURL = self.backURL {
                    self.frontPreviewURL = frontURL
                    self.backPreviewURL = backURL
                }
                
                if let context = self.storedContext {
                    self.processingStartTime = CFAbsoluteTimeGetCurrent()
                    print("Starting video processing at: \(self.processingStartTime)")
                } else {
                    print("No context available for video processing")
                }
            }
        }
    }
}

extension CameraController {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === frontAudioOutput {
            if isRecording, let audioInputWriter = audioInputWriter, audioInputWriter.isReadyForMoreMediaData {
                if assetWriter?.status == .unknown {
                    let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    assetWriter?.startSession(atSourceTime: startTime)
                }
                audioInputWriter.append(sampleBuffer)
            }
        } else if output === frontVideoDataOutput {
            if isRecording {
                processFrontSampleBuffer(sampleBuffer)
            }
        } else if output === backVideoDataOutput {
            if isRecording {
                processBackSampleBuffer(sampleBuffer)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    }
}
