import Foundation
import Photos
import UIKit
import TikTokOpenShareSDK

class TikTokSharingService {
    static let shared = TikTokSharingService()
    private init() {}

    enum TikTokShareState {
        case postedWithSuccess
        case failedToPost
    }

    func shareToTikTok(videoURL: URL, redriectURI: String, completion: @escaping (TikTokShareState, String) -> Void) {
        Task {
            do {
                let videoIdentifier = try await self.saveVideoToPhotosAndGetIdentifier(video: videoURL)
                try await self.shareVideoToTikTok(localIdentifier: videoIdentifier, redriectURI: redriectURI)
                DispatchQueue.main.async {
                    completion(.postedWithSuccess, "Video shared to TikTok successfully!")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failedToPost, error.localizedDescription)
                }
            }
        }
    }

    private func saveVideoToPhotosAndGetIdentifier(video: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video)
                        let placeholder = request?.placeholderForCreatedAsset
                        let localIdentifier = placeholder?.localIdentifier
                        continuation.resume(returning: localIdentifier ?? "")
                    }) { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                    }
                default:
                    continuation.resume(throwing: NSError(domain: "PhotoLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authorized"]))
                }
            }
        }
    }

    private func shareVideoToTikTok(localIdentifier: String, redriectURI: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let shareRequest = TikTokShareRequest(
                    localIdentifiers: [localIdentifier],
                    mediaType: .video,
                    redirectURI: redriectURI
                )
                shareRequest.shareFormat = .normal
                shareRequest.send { response in
                    if let shareResponse = response as? TikTokShareResponse {
                        if shareResponse.errorCode == .noError {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: NSError(
                                domain: "TikTok",
                                code: Int(shareResponse.errorCode.rawValue),
                                userInfo: [NSLocalizedDescriptionKey: shareResponse.errorDescription ?? "Unknown error"]
                            ))
                        }
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "TikTok",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
                        ))
                    }
                }
            }
        }
    }
} 