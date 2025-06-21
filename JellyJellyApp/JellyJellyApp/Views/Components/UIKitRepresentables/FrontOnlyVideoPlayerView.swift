import SwiftUI
import AVKit

struct FrontOnlyVideoPlayerView: UIViewControllerRepresentable {
    let frontURL: URL
    let backURL: URL
    let cameraSwitchTimestamps: [Double]
    let initialCameraPosition: AVCaptureDevice.Position
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = FrontOnlyVideoPlayerController(frontURL: frontURL, backURL: backURL, cameraSwitchTimestamps: cameraSwitchTimestamps, initialCameraPosition: initialCameraPosition)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}

class FrontOnlyVideoPlayerController: UIViewController {
    let frontPlayer: AVPlayer
    let backPlayer: AVPlayer
    let frontLayer: AVPlayerLayer
    let backLayer: AVPlayerLayer
    let cameraSwitchTimestamps: [Double]
    let initialCameraPosition: AVCaptureDevice.Position
    private var checkTimer: Timer?
    private var frontDuration: Double = 0
    private var backDuration: Double = 0
    private var currentCamera: AVCaptureDevice.Position = .front
    private var currentSegmentIndex: Int = 0
    
    private let setupStartTime = CFAbsoluteTimeGetCurrent()
    private var viewDidLoadTime: CFAbsoluteTime = 0
    private var playbackReadyTime: CFAbsoluteTime = 0
    
    private var frontStatusObserver: NSKeyValueObservation?
    private var backStatusObserver: NSKeyValueObservation?
    private var frontItemObserver: NSKeyValueObservation?
    private var backItemObserver: NSKeyValueObservation?
    private var frontEndObserver: NSObjectProtocol?
    private var backEndObserver: NSObjectProtocol?
    private var appWillResignActiveObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?
    
    init(frontURL: URL, backURL: URL, cameraSwitchTimestamps: [Double], initialCameraPosition: AVCaptureDevice.Position) {        
        self.frontPlayer = AVPlayer(url: frontURL)
        self.backPlayer = AVPlayer(url: backURL)
        self.cameraSwitchTimestamps = cameraSwitchTimestamps
        self.initialCameraPosition = initialCameraPosition
        
        self.frontPlayer.automaticallyWaitsToMinimizeStalling = false
        self.backPlayer.automaticallyWaitsToMinimizeStalling = false
        
        self.frontLayer = AVPlayerLayer(player: frontPlayer)
        self.backLayer = AVPlayerLayer(player: backPlayer)
        
        super.init(nibName: nil, bundle: nil)
        
        self.backPlayer.volume = 0.0
        
        setupReadinessObservers()
        setupEndObservers()
        setupAppLifecycleObservers()
        
        if let frontAsset = frontPlayer.currentItem?.asset {
            Task {
                do {
                    _ = try await frontAsset.load(.duration, .isPlayable)
                    await MainActor.run {
                        self.checkIfBothReady()
                    }
                } catch {
                    print("Error loading front asset: \(error)")
                }
            }
        }
        
        if let backAsset = backPlayer.currentItem?.asset {
            Task {
                do {
                    _ = try await backAsset.load(.duration, .isPlayable)
                    await MainActor.run {
                        self.checkIfBothReady()
                    }
                } catch {
                    print("Error loading back asset: \(error)")
                }
            }
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupReadinessObservers() {
        frontStatusObserver = frontPlayer.observe(\.status, options: [.new]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.checkIfBothReady()
            }
        }
        
        backStatusObserver = backPlayer.observe(\.status, options: [.new]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.checkIfBothReady()
            }
        }
        
        frontItemObserver = frontPlayer.observe(\.currentItem?.status, options: [.new]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.checkIfBothReady()
            }
        }
        
        backItemObserver = backPlayer.observe(\.currentItem?.status, options: [.new]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.checkIfBothReady()
            }
        }
    }
    
    private func setupEndObservers() {
        frontEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: frontPlayer.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleVideoEnd()
        }
        
        backEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: backPlayer.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleVideoEnd()
        }
    }
    
    private func setupAppLifecycleObservers() {
        appWillResignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppWillResignActive()
        }
        
        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }
    }
    
    private func handleAppWillResignActive() {
        frontPlayer.pause()
        backPlayer.pause()
    }
    
    private func handleAppDidBecomeActive() {
        restartVideos()
    }
    
    private func handleVideoEnd() {
        frontPlayer.seek(to: .zero)
        backPlayer.seek(to: .zero)
        
        frontPlayer.play()
        backPlayer.play()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewDidLoadTime = CFAbsoluteTimeGetCurrent()
        
        frontLayer.videoGravity = .resizeAspectFill
        backLayer.videoGravity = .resizeAspectFill
        
        frontLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        
        view.layer.addSublayer(frontLayer)
        view.layer.addSublayer(backLayer)
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        checkIfBothReady()
    }
    
    private func checkIfBothReady() {
        guard let frontItem = frontPlayer.currentItem,
              let backItem = backPlayer.currentItem,
              frontItem.status == .readyToPlay,
              backItem.status == .readyToPlay else {
            return
        }
        
        guard playbackReadyTime == 0 else { return }
        
        playbackReadyTime = CFAbsoluteTimeGetCurrent()
        let totalSetupTime = (playbackReadyTime - setupStartTime) * 1000
        let timeFromViewLoad = (playbackReadyTime - viewDidLoadTime) * 1000
        
        print("   Total setup time: \(String(format: "%.1f", totalSetupTime))ms")
        print("   Time from viewDidLoad: \(String(format: "%.1f", timeFromViewLoad))ms")
        
        frontDuration = frontItem.duration.seconds
        backDuration = backItem.duration.seconds
        
        self.updateLayerFrames()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            self.startPlayback()
        }
    }
    
    private func startPlayback() {
        updateLayerFrames()
        
        guard let frontItem = frontPlayer.currentItem,
              let backItem = backPlayer.currentItem,
              frontItem.status == .readyToPlay,
              backItem.status == .readyToPlay else {
            return
        }
        
        frontPlayer.seek(to: .zero)
        backPlayer.seek(to: .zero)
        
        frontPlayer.play()
        backPlayer.play()
        
        startMonitoring()
    }
    
    private func startMonitoring() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkVideoProgress()
        }
    }
    
    private func checkVideoProgress() {
        let frontTime = frontPlayer.currentTime().seconds
        let backTime = backPlayer.currentTime().seconds
        
        let timeDifference = abs(frontTime - backTime)
        if timeDifference > 0.5 {
            let targetTime = min(frontTime, backTime)
            let cmTime = CMTime(seconds: targetTime, preferredTimescale: 600)
            frontPlayer.seek(to: cmTime)
            backPlayer.seek(to: cmTime)
        }
        
        let frontFinished = frontDuration > 0 && frontTime >= (frontDuration - 0.1)
        let backFinished = backDuration > 0 && backTime >= (backDuration - 0.1)
        
        if frontFinished || backFinished {
            restartVideos()
        }
        
        if !cameraSwitchTimestamps.isEmpty {
            updateCameraBasedOnTimestamps(currentTime: frontTime)
        } else {
            if currentCamera != initialCameraPosition {
                currentCamera = initialCameraPosition
                updateCameraVisibility()
            }
        }
    }
    
    private func updateCameraBasedOnTimestamps(currentTime: Double) {
        var newSegmentIndex = 0
        
        for (index, timestamp) in cameraSwitchTimestamps.enumerated() {
            if currentTime >= timestamp {
                newSegmentIndex = index + 1
            } else {
                break
            }
        }
        
        let newCamera: AVCaptureDevice.Position
        if initialCameraPosition == .front {
            newCamera = newSegmentIndex % 2 == 0 ? .front : .back
        } else {
            newCamera = newSegmentIndex % 2 == 0 ? .back : .front
        }
        
        if newCamera != currentCamera || newSegmentIndex != currentSegmentIndex {
            currentCamera = newCamera
            currentSegmentIndex = newSegmentIndex
            updateCameraVisibility()
        }
    }
    
    private func updateCameraVisibility() {
        if currentCamera == .front {
            frontLayer.opacity = 1.0
            backLayer.opacity = 0.0
        } else {
            frontLayer.opacity = 0.0
            backLayer.opacity = 1.0
        }
    }
    
    private func restartVideos() {
        checkTimer?.invalidate()
        
        frontPlayer.seek(to: .zero)
        backPlayer.seek(to: .zero)
        
        guard let frontItem = frontPlayer.currentItem,
              let backItem = backPlayer.currentItem,
              frontItem.status == .readyToPlay,
              backItem.status == .readyToPlay else {
            return
        }
        
        frontPlayer.play()
        backPlayer.play()
        
        startMonitoring()
    }
    
    private func updateLayerFrames() {
        frontLayer.frame = view.bounds
        backLayer.frame = view.bounds
        
        currentCamera = initialCameraPosition
        updateCameraVisibility()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLayerFrames()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanup()
    }
    
    private func cleanup() {
        frontStatusObserver?.invalidate()
        backStatusObserver?.invalidate()
        frontItemObserver?.invalidate()
        backItemObserver?.invalidate()
        
        if let frontEnd = frontEndObserver {
            NotificationCenter.default.removeObserver(frontEnd)
        }
        if let backEnd = backEndObserver {
            NotificationCenter.default.removeObserver(backEnd)
        }
        if let appWillResign = appWillResignActiveObserver {
            NotificationCenter.default.removeObserver(appWillResign)
        }
        if let appDidBecome = appDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(appDidBecome)
        }
        
        checkTimer?.invalidate()
        checkTimer = nil
        frontPlayer.pause()
        backPlayer.pause()
    }
    
    deinit {
        cleanup()
    }
} 
