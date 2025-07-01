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

class CameraController: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureMultiCamSession()
     let frontOutput = AVCaptureMovieFileOutput()
     let backOutput = AVCaptureMovieFileOutput()
    let storage = Storage.storage()
     let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
    
    let frontAudioOutput = AVCaptureAudioDataOutput()
     let audioOutQueue = DispatchQueue(label: "com.jellyjelly.CameraController.audioDataOutputQueue")
    
    weak var previewView: CameraPreviewUIView?
    var frontURL: URL?
    var backURL: URL?
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
    
     var isTorchActive = false
    
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
    
     var frontCamera: AVCaptureDevice?
     var backCamera: AVCaptureDevice?
     var frontInput: AVCaptureDeviceInput?
     var backInput: AVCaptureDeviceInput?
     var audioInput: AVCaptureDeviceInput?
     var audioWriterInput: AVAssetWriterInput?
     var isSessionSetup = false
     var frontInitialZoom: CGFloat = 1.0
     var backInitialZoom: CGFloat = 1.0
    
     var recordingTimer: Timer?
     let maxRecordingTime = 15000
    
    var recordingCompletionCount = 0
    var storedContext: NSManagedObjectContext?
    var processingStartTime: CFAbsoluteTime = 0
     var lastRecordedVideo: RecordedVideo?
    var cameraSwitchTimestamps: [CFAbsoluteTime] = []
     var recordingStartTime: CFAbsoluteTime = 0
    var initialCameraPosition: AVCaptureDevice.Position = .front
    
    var onVideoProcessed: (() -> Void)?
    
    var assetWriter: AVAssetWriter?
     var videoInput: AVAssetWriterInput?
     var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
     var ciContext = CIContext()
     var frameCount: Int64 = 0
     var startTime: CMTime?
     var outputURL: URL?
     var frontFrameBuffer: [CMTime: CMSampleBuffer] = [:]
     var backFrameBuffer: [CMTime: CMSampleBuffer] = [:]
     var lastFrontTime: CMTime?
     var lastBackTime: CMTime?
     var isWriterReady: Bool = false
     var isAudioReady = false
     var audioSessionStarted = false
     let writerSessionLock = NSLock()
    var audioInputWriter: AVAssetWriterInput?
     var hasPreWarmedWriter = false
     let frameBufferLock = NSLock()
    var frontVideoDataOutput: AVCaptureVideoDataOutput?
    var backVideoDataOutput: AVCaptureVideoDataOutput?
    
     var backCameraType: AVCaptureDevice.DeviceType?
    
    @Published var frontAudioLevel: CGFloat = 0.0
     var audioLevelTimer: Timer?
    
     var lastAppendedVideoTime: CMTime?
    
     func configureAudioSessionForFrontCameraRecording() throws {
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
    
     func deactivateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(false, options: [.notifyOthersOnDeactivation])
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

     func applyInitialZoomSettings() {
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
}
