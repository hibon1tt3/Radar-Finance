import LocalAuthentication
import SwiftUI

class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @AppStorage("useBiometricAuth") private var useBiometricAuth = false
    @AppStorage("passcode") private var storedPasscode: String = ""
    @Published var showingPasscodeSetup = false
    
    init() {
        if !useBiometricAuth {
            isAuthenticated = true
        }
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Lock when app goes to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.useBiometricAuth == true {
                self?.isAuthenticated = false
            }
        }
    }
    
    func authenticate() {
        guard useBiometricAuth else { return }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "Unlock Radar Finance") { success, _ in
                DispatchQueue.main.async { [weak self] in
                    if success {
                        self?.isAuthenticated = true
                    }
                }
            }
        }
    }
    
    func authenticateWithPasscode(_ passcode: String) -> Bool {
        if passcode == storedPasscode {
            isAuthenticated = true
            return true
        }
        return false
    }
    
    func toggleBiometricAuth(enabled: Bool) {
        if enabled {
            if !hasPasscode() {
                // Show passcode setup first if no passcode exists
                showingPasscodeSetup = true
                // Don't enable Face ID yet - we'll do it after passcode is set
                return
            }
            
            requestFaceIDAuth()
        } else {
            // Disable biometric auth
            useBiometricAuth = false
            isAuthenticated = true
        }
    }
    
    private func requestFaceIDAuth() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Enable Face ID") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.useBiometricAuth = true
                        self.isAuthenticated = true
                    }
                }
            }
        }
    }
    
    func completePasscodeSetup(passcode: String) {
        setPasscode(passcode)
        showingPasscodeSetup = false
        // Now that we have a passcode, request Face ID auth
        requestFaceIDAuth()
    }
    
    func setPasscode(_ passcode: String) {
        storedPasscode = passcode
    }
    
    func hasPasscode() -> Bool {
        !storedPasscode.isEmpty
    }
    
    func cancelPasscodeSetup() {
        showingPasscodeSetup = false
        useBiometricAuth = false
    }
} 
