import Foundation
import Photos
import UIKit

class InstagramSharingService {
    static let shared = InstagramSharingService()
    
    private init() {}
    
    func shareToSocialMediaUniversal(videoURL: URL, completion: @escaping (Bool, String) -> Void) {
        saveToPhotos(videoURL: videoURL) { success, message in
            if success {
                self.shareVideoToSocialMediaUniversal(videoURL: videoURL, completion: completion)
            } else {
                completion(false, message)
            }
        }
    }
    
    private func saveToPhotos(videoURL: URL, completion: @escaping (Bool, String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false, "Photos access denied")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, "Video saved to Photos!")
                    } else {
                        completion(false, "Failed to save video: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    private func shareVideoToSocialMediaUniversal(videoURL: URL, completion: @escaping (Bool, String) -> Void) {
        guard UIApplication.shared.canOpenURL(URL(string: "instagram://app")!) else {
            completion(false, "Instagram not installed")
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let shareURL = documentsPath.appendingPathComponent("social_share.mp4")
        
        do {
            if FileManager.default.fileExists(atPath: shareURL.path) {
                try FileManager.default.removeItem(at: shareURL)
            }
            
            try FileManager.default.copyItem(at: videoURL, to: shareURL)
            
            guard let videoData = try? Data(contentsOf: videoURL) else {
                completion(false, "Failed to read video data")
                return
            }
            
            let pasteboardItems: [[String: Any]] = [
                [
                    "com.instagram.video": videoData,
                    "com.instagram.sharedSticker.appID": "611668754796083" 
                ]
            ]
            
            UIPasteboard.general.setItems(pasteboardItems, options: [
                .expirationDate: Date().addingTimeInterval(60 * 5) 
            ])
            
            if let instagramURL = URL(string: "instagram://library?AssetPath=\(shareURL.absoluteString)"),
               UIApplication.shared.canOpenURL(instagramURL) {
                UIApplication.shared.open(instagramURL) { success in
                    DispatchQueue.main.async {
                        completion(success, success ? "Video passed to Instagram! Choose where to share inside the app." : "Failed to open Instagram sharing interface")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.presentSocialMediaDocumentInteraction(videoURL: shareURL, completion: completion)
                }
            }
            
        } catch {
            completion(false, "Failed to prepare video for social media: \(error.localizedDescription)")
        }
    }
    
    private func presentSocialMediaDocumentInteraction(videoURL: URL, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                let documentController = UIDocumentInteractionController(url: videoURL)
                
                let instagramUTIs = [
                    "com.instagram.photo",
                    "com.instagram.video",
                    "com.instagram.exclusivegram",
                    "public.movie"
                ]
                
                for uti in instagramUTIs {
                    documentController.uti = uti
                    if documentController.presentOpenInMenu(from: CGRect(x: 0, y: 0, width: 1, height: 1), in: rootViewController.view, animated: true) {
                        completion(true, "Instagram sharing menu opened! Choose your preferred sharing option.")
                        return
                    }
                }
                
                documentController.uti = nil
                if documentController.presentOpenInMenu(from: CGRect(x: 0, y: 0, width: 1, height: 1), in: rootViewController.view, animated: true) {
                    completion(true, "Sharing menu opened! Select Instagram to share.")
                } else {
                    completion(false, "Unable to open sharing interface. Try 'Open Instagram' option instead.")
                }
            } else {
                completion(false, "Unable to present sharing interface")
            }
        }
    }
} 
