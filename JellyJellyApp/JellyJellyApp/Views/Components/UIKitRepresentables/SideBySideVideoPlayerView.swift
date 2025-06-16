import SwiftUI
import AVKit

struct SideBySideVideoPlayerView: UIViewControllerRepresentable {
    let frontURL: URL
    let backURL: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = SideBySideVideoPlayerController(frontURL: frontURL, backURL: backURL)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}

class SideBySideVideoPlayerController: UIViewController {
    let frontPlayer: AVPlayer
    let backPlayer: AVPlayer
    let frontLayer: AVPlayerLayer
    let backLayer: AVPlayerLayer
    let backgroundLayer: AVPlayerLayer
    private var checkTimer: Timer?
    private var frontDuration: Double = 0
    private var backDuration: Double = 0
    
    private let setupStartTime = CFAbsoluteTimeGetCurrent()
    private var viewDidLoadTime: CFAbsoluteTime = 0
    private var playbackReadyTime: CFAbsoluteTime = 0
    
    private var frontStatusObserver: NSKeyValueObservation?
    private var backStatusObserver: NSKeyValueObservation?
    private var frontItemObserver: NSKeyValueObservation?
    private var backItemObserver: NSKeyValueObservation?
    private var frontEndObserver: NSObjectProtocol?
    private var backEndObserver: NSObjectProtocol?
    
    init(frontURL: URL, backURL: URL) {        
        self.frontPlayer = AVPlayer(url: frontURL)
        self.backPlayer = AVPlayer(url: backURL)
        
        self.frontPlayer.automaticallyWaitsToMinimizeStalling = false
        self.backPlayer.automaticallyWaitsToMinimizeStalling = false
        
        self.frontLayer = AVPlayerLayer(player: frontPlayer)
        self.backLayer = AVPlayerLayer(player: backPlayer)
        self.backgroundLayer = AVPlayerLayer(player: frontPlayer)
        
        super.init(nibName: nil, bundle: nil)
        
        self.backPlayer.volume = 0.0
        
        setupReadinessObservers()
        setupEndObservers()
        
        if let frontAsset = frontPlayer.currentItem?.asset {
            frontAsset.loadValuesAsynchronously(forKeys: ["duration", "playable"]) { [weak self] in
                DispatchQueue.main.async {
                    self?.checkIfBothReady()
                }
            }
        }
        
        if let backAsset = backPlayer.currentItem?.asset {
            backAsset.loadValuesAsynchronously(forKeys: ["duration", "playable"]) { [weak self] in
                DispatchQueue.main.async {
                    self?.checkIfBothReady()
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
    
    private func handleVideoEnd() {
        frontPlayer.seek(to: .zero)
        backPlayer.seek(to: .zero)
        
        frontPlayer.play()
        backPlayer.play()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewDidLoadTime = CFAbsoluteTimeGetCurrent()
        let timeFromStart = (viewDidLoadTime - setupStartTime) * 1000
        
        backgroundLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(backgroundLayer)
        
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        view.addSubview(blurEffectView)
        
        frontLayer.videoGravity = .resizeAspect
        backLayer.videoGravity = .resizeAspect
        
        frontLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        backgroundLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        
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
        let halfWidth = view.bounds.width / 2
        let fullHeight = view.bounds.height
        
        backgroundLayer.frame = view.bounds
        
        let frontFrame = CGRect(x: 0, y: 0, width: halfWidth, height: fullHeight)
        let backFrame = CGRect(x: halfWidth, y: 0, width: halfWidth, height: fullHeight)
        
        frontLayer.frame = frontFrame
        backLayer.frame = backFrame
        
        frontLayer.position = CGPoint(x: halfWidth/2, y: fullHeight/2)
        backLayer.position = CGPoint(x: halfWidth + halfWidth/2, y: fullHeight/2)
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
        
        checkTimer?.invalidate()
        checkTimer = nil
        frontPlayer.pause()
        backPlayer.pause()
    }
    
    deinit {
        cleanup()
    }
} 