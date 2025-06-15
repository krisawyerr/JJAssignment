import SwiftUI
import AVKit

struct DualVideoPlayerView: UIViewControllerRepresentable {
    let frontURL: URL
    let backURL: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = DualVideoPlayerController(frontURL: frontURL, backURL: backURL)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}

class DualVideoPlayerController: UIViewController {
    let frontPlayer: AVPlayer
    let backPlayer: AVPlayer
    let frontLayer: AVPlayerLayer
    let backLayer: AVPlayerLayer
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
    
    init(frontURL: URL, backURL: URL) {        
        self.frontPlayer = AVPlayer(url: frontURL)
        self.backPlayer = AVPlayer(url: backURL)
        
        self.frontPlayer.automaticallyWaitsToMinimizeStalling = false
        self.backPlayer.automaticallyWaitsToMinimizeStalling = false
        
        self.frontLayer = AVPlayerLayer(player: frontPlayer)
        self.backLayer = AVPlayerLayer(player: backPlayer)
        
        super.init(nibName: nil, bundle: nil)
        
        self.backPlayer.volume = 0.0
        
        setupReadinessObservers()
        
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewDidLoadTime = CFAbsoluteTimeGetCurrent()
        let timeFromStart = (viewDidLoadTime - setupStartTime) * 1000
        
        frontLayer.videoGravity = .resizeAspectFill
        backLayer.videoGravity = .resizeAspectFill
        
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
        frontPlayer.play()
        backPlayer.play()
        startMonitoring()
    }
    
    private func startMonitoring() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkVideoProgress()
        }
    }
    
    private func checkVideoProgress() {
        let frontTime = frontPlayer.currentTime().seconds
        let backTime = backPlayer.currentTime().seconds
        
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.frontPlayer.play()
            self.backPlayer.play()
            
            self.startMonitoring()
            print("Videos restarted")
        }
    }
    
    private func updateLayerFrames() {
        let halfHeight = view.bounds.height / 2
        frontLayer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: halfHeight)
        backLayer.frame = CGRect(x: 0, y: halfHeight, width: view.bounds.width, height: halfHeight)
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
        
        checkTimer?.invalidate()
        checkTimer = nil
        frontPlayer.pause()
        backPlayer.pause()
    }
    
    deinit {
        cleanup()
    }
}
