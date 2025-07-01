import AVFoundation
import CoreImage
import CoreData
import Foundation

extension CameraController {
     func setupWriter() {
        guard let outputURL = outputURL else { return }
        cleanupWriter()
        lastAppendedVideoTime = nil
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
     func cleanupWriter() {
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
        lastAppendedVideoTime = nil
        if let outputURL = outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
    }
     func finishWriter() {
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
     func tryToMergeFrame(at time: CMTime) {
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
     func compositeAndWrite(frontBuffer: CMSampleBuffer, backBuffer: CMSampleBuffer, at time: CMTime) {
        guard let assetWriter = assetWriter, let videoInput = videoInput, let pixelBufferAdaptor = pixelBufferAdaptor, videoInput.isReadyForMoreMediaData, assetWriter.status == .writing else { return }
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
            if let lastTime = lastAppendedVideoTime, time <= lastTime {
                print("Skipping frame: non-increasing presentation time (last: \(lastTime.seconds), current: \(time.seconds))")
                return
            }
            let success = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: time)
            if !success {
                print("Failed to append pixel buffer at time: \(time.seconds)")
            } else {
                lastAppendedVideoTime = time
                frameCount += 1
            }
        }
    }
     func createWatermarkedVersion(originalURL: URL, context: NSManagedObjectContext, video: RecordedVideo) {
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
} 
