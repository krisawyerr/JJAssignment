import AVFoundation
import Foundation

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
                if self.storedContext != nil {
                    self.processingStartTime = CFAbsoluteTimeGetCurrent()
                    print("Starting video processing at: \(self.processingStartTime)")
                } else {
                    print("No context available for video processing")
                }
            }
        }
    }
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
