import Foundation
import CoreData
import FirebaseStorage

extension CameraController {
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
} 