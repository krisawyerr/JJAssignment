import Foundation
import AVFoundation
import UIKit
import CoreImage

class VideoWatermarkService {
    static let shared = VideoWatermarkService()
    
    private init() {}
    
    func addWatermarkToVideo(inputURL: URL, outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: inputURL)
        
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(NSError(domain: "VideoWatermarkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])))
            return
        }
        
        let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        try? compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        if let audioTrack = asset.tracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }
        
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        instruction.layerInstructions = [layerInstruction]
        
        videoComposition.instructions = [instruction]
        
        videoComposition.animationTool = createWatermarkAnimationTool(videoSize: videoTrack.naturalSize)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "VideoWatermarkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(exportSession.error ?? NSError(domain: "VideoWatermarkError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])))
                case .cancelled:
                    completion(.failure(NSError(domain: "VideoWatermarkError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
                default:
                    completion(.failure(NSError(domain: "VideoWatermarkError", code: -5, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"])))
                }
            }
        }
    }
    
    private func createWatermarkAnimationTool(videoSize: CGSize) -> AVVideoCompositionCoreAnimationTool {
        let watermarkLayer = createWatermarkLayer(videoSize: videoSize)
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(watermarkLayer)
        
        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }
    
    private func createWatermarkLayer(videoSize: CGSize) -> CALayer {
        let watermarkLayer = CALayer()
        
        let textLayer = CATextLayer()
        textLayer.string = "JellyJelly"
        textLayer.font = UIFont(name: "Ranchers-Regular", size: 48)
        textLayer.fontSize = 48
        textLayer.foregroundColor = UIColor.white.cgColor
        
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.shadowOpacity = 0.8
        textLayer.shadowRadius = 3
        
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Ranchers-Regular", size: 48) ?? UIFont.systemFont(ofSize: 48)
        ]
        let textSize = "JellyJelly".size(withAttributes: textAttributes)
        
        let padding: CGFloat = 20
        let textWidth = textSize.width
        let textHeight = textSize.height
        let x = videoSize.width - textWidth - padding
        let y = padding
        
        textLayer.frame = CGRect(x: x, y: y, width: textWidth, height: textHeight)
        textLayer.alignmentMode = .left
        textLayer.contentsScale = UIScreen.main.scale
        
        watermarkLayer.addSublayer(textLayer)
        watermarkLayer.frame = CGRect(origin: .zero, size: videoSize)
        
        return watermarkLayer
    }
}