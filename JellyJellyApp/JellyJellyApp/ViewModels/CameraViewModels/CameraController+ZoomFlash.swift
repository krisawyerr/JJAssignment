import AVFoundation
import Foundation
import SwiftUI

extension CameraController {
    func setZoomFactor(_ factor: CGFloat, forCamera position: AVCaptureDevice.Position) {
        guard let device = position == .front ? frontCamera : backCamera else { return }
        do {
            try device.lockForConfiguration()
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 42.0)
            let clampedFactor = min(max(factor, 1.0), maxZoom)
            if position == .front {
                frontZoomFactor = clampedFactor
                device.videoZoomFactor = clampedFactor
            } else {
                backZoomFactor = clampedFactor
                device.videoZoomFactor = clampedFactor
                exactBackZoomFactor = clampedFactor
                if clampedFactor <= 1.0 {
                    currentBackZoom = .oneX
                } else {
                    currentBackZoom = .twoX
                }
            }
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom factor: \(error.localizedDescription)")
        }
    }
    func cycleBackCameraZoom() {
        guard let backCamera = backCamera else { return }
        let maxZoom = backCamera.activeFormat.videoMaxZoomFactor
        var nextZoom = currentBackZoom.next
        while nextZoom.zoomFactor > maxZoom && nextZoom != currentBackZoom {
            nextZoom = nextZoom.next
        }
        currentBackZoom = nextZoom
        exactBackZoomFactor = currentBackZoom.zoomFactor
        setZoomFactor(currentBackZoom.zoomFactor, forCamera: .back)
        print("Back camera zoom changed to: \(currentBackZoom.displayText)")
    }
    func getMaxBackCameraZoom() -> CGFloat {
        guard let backCamera = backCamera else { return 1.0 }
        return min(backCamera.activeFormat.videoMaxZoomFactor, 42.0)
    }
    func getBackZoomDisplayText() -> String {
        let tolerance: CGFloat = 0.1
        if abs(exactBackZoomFactor - currentBackZoom.zoomFactor) < tolerance {
            return currentBackZoom.displayText
        } else {
            return String(format: "%.1fx", exactBackZoomFactor / 2)
        }
    }
    func toggleFlash() {
        isFlashOn.toggle()
        if isRecording {
            if isFlashOn {
                turnFlashOff()
            } else {
                turnFlashOn()
            }
        }
    }
    func turnFlashOn() {
        guard let backCamera = backCamera else { return }
        do {
            try backCamera.lockForConfiguration()
            if backCamera.isTorchModeSupported(.on) {
                backCamera.torchMode = .on
                isTorchActive = true
            }
            backCamera.unlockForConfiguration()
        } catch {
            print("Error turning flash on: \(error.localizedDescription)")
        }
    }
    func turnFlashOff() {
        guard let backCamera = backCamera else { return }
        do {
            try backCamera.lockForConfiguration()
            if backCamera.isTorchModeSupported(.off) {
                backCamera.torchMode = .off
                isTorchActive = false
            }
            backCamera.unlockForConfiguration()
        } catch {
            print("Error turning flash off: \(error.localizedDescription)")
        }
    }
} 