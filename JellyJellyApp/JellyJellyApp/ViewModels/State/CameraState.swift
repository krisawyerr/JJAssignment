import Foundation
import Combine

class CameraState: ObservableObject {
    @Published var cameraController = CameraController()
    
    init() {
        setupCamera()
    }
    
    func setupCamera() {
        cameraController.setupCamera()
    }
} 