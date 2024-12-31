import SwiftUI
import LocalAuthentication

struct BiometricLockView: View {
    @Binding var isUnlocked: Bool
    @State private var error: String?
    
    var body: some View {
        VStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .padding()
            
            Text("Radar Finance is locked")
                .font(.title2)
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button("Unlock") {
                authenticate()
            }
            .padding()
        }
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "Unlock Radar Finance") { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    } else if let error = error {
                        self.error = error.localizedDescription
                    }
                }
            }
        } else {
            self.error = error?.localizedDescription ?? "Biometric authentication not available"
        }
    }
} 
