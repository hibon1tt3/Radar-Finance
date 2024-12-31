import SwiftUI
import AVFoundation

class CameraPermissionManager: ObservableObject {
    @AppStorage("isCameraEnabled") var isCameraEnabled = false
    
    init() {
        // Setup notification observer for when app becomes active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updatePermissionStatus),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    var isCameraAvailable: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    @objc private func updatePermissionStatus() {
        // Update isCameraEnabled based on actual permission status
        DispatchQueue.main.async {
            self.isCameraEnabled = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
    }
    
    func checkInitialCameraPermission() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isCameraEnabled = granted
                }
            }
        }
    }
    
    func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            // First time request
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isCameraEnabled = granted
                }
            }
        case .denied, .restricted:
            // Open settings if permission was previously denied
            DispatchQueue.main.async {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        case .authorized:
            DispatchQueue.main.async {
                self.isCameraEnabled = true
            }
        @unknown default:
            break
        }
    }
    
    func disableCamera() {
        isCameraEnabled = false
    }
} 