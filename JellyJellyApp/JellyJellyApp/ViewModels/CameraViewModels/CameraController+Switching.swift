import AVFoundation
import Foundation

extension CameraController {
    func flipCameraInFrontOnlyMode() {
        print("flipCameraInFrontOnlyMode called - current mode: \(cameraLayoutMode), current active camera: \(activeCameraInFrontOnlyMode)")
        if isRecording && isFlashOn {
            if getCurrentActiveCameraPosition() == .front {
                turnFlashOn()
            } else {
                turnFlashOff()
            }
        }
        let _ = activeCameraInFrontOnlyMode
        activeCameraInFrontOnlyMode = activeCameraInFrontOnlyMode == .front ? .back : .front
        if isRecording {
            recordCameraSwitch()
        }
        previewView?.flipCameraInFrontOnlyMode()
    }
    func getCurrentActiveCameraPosition() -> AVCaptureDevice.Position {
        if cameraLayoutMode == .frontOnly {
            return activeCameraInFrontOnlyMode
        } else {
            return .back
        }
    }
} 