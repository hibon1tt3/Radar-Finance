import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @State private var showingPasscodeEntry = false
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.2),
                    Color.blue.opacity(0.1),
                    Color.blue.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .hueRotation(.degrees(isAnimating ? 45 : 0))
            .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: 30) {
                Spacer()
                
                // App icon and title
                VStack(spacing: 20) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "banknote")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue.gradient)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text("Radar Finance")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Authentication buttons
                VStack(spacing: 15) {
                    Button(action: {
                        authService.authenticate()
                    }) {
                        HStack {
                            Image(systemName: "faceid")
                                .font(.title2)
                            Text("Unlock with Face ID")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.blue.gradient)
                        )
                        .foregroundColor(.white)
                        .contentShape(Rectangle())
                    }
                    
                    Button(action: {
                        showingPasscodeEntry = true
                    }) {
                        Text("Use Passcode")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
        }
        .onAppear {
            isAnimating = true
            if !authService.hasPasscode() {
                showingPasscodeEntry = true
            }
        }
        .sheet(isPresented: $showingPasscodeEntry) {
            PasscodeEntryView(isSetup: !authService.hasPasscode())
                .interactiveDismissDisabled(!authService.hasPasscode())
        }
    }
}

struct NumberPadRow: View {
    let rowIndex: Int
    let addDigit: (String) -> Void
    
    var body: some View {
        HStack(spacing: 30) {
            ForEach(1...3, id: \.self) { column in
                let number = (rowIndex * 3) + column
                Button {
                    addDigit("\(number)")
                    HapticManager.shared.tap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 75, height: 75)
                        
                        Text("\(number)")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(NumberPadButtonStyle())
            }
        }
    }
}

struct PasscodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthenticationService
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var showingError = false
    @State private var isConfirming = false
    let isSetup: Bool
    
    private var titleText: String {
        if isSetup {
            return isConfirming ? "Confirm Passcode" : "Create Passcode"
        }
        return "Enter Passcode"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Spacer()
                
                // Title and description
                VStack(spacing: 8) {
                    Text(titleText)
                        .font(.title2)
                        .bold()
                    
                    if isSetup && !isConfirming {
                        Text("This passcode will be used when Face ID is unavailable")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Passcode dots
                HStack(spacing: 20) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index < currentPasscode.count ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical, 20)
                
                // Number pad
                VStack(spacing: 15) {
                    ForEach(0..<3) { row in
                        NumberPadRow(rowIndex: row, addDigit: addDigit)
                    }
                    
                    // Bottom row with special buttons
                    HStack(spacing: 30) {
                        // Backspace button
                        Button {
                            if !currentPasscode.isEmpty {
                                if isConfirming {
                                    confirmPasscode.removeLast()
                                } else {
                                    passcode.removeLast()
                                }
                                HapticManager.shared.tap()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 75, height: 75)
                                
                                Image(systemName: "delete.left")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(NumberPadButtonStyle())
                        
                        Button {
                            addDigit("0")
                            HapticManager.shared.tap()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 75, height: 75)
                                
                                Text("0")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                        }
                        .buttonStyle(NumberPadButtonStyle())
                        
                        // Cancel button
                        Button {
                            dismiss()
                            if isSetup {
                                authService.cancelPasscodeSetup()
                            }
                            HapticManager.shared.tap()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 75, height: 75)
                                
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(NumberPadButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .onChange(of: currentPasscode) { _, newValue in
                if newValue.count == 4 {
                    handleComplete()
                }
            }
            .alert("Passcodes Don't Match", isPresented: $showingError) {
                Button("OK", role: .cancel) {
                    isConfirming = false
                    confirmPasscode = ""
                }
            } message: {
                Text("Please try again.")
            }
        }
    }
    
    private var currentPasscode: String {
        isConfirming ? confirmPasscode : passcode
    }
    
    private func addDigit(_ digit: String) {
        guard currentPasscode.count < 4 else { return }
        if isConfirming {
            confirmPasscode += digit
        } else {
            passcode += digit
        }
    }
    
    private func handleComplete() {
        if isSetup {
            if isConfirming {
                if passcode == confirmPasscode {
                    authService.completePasscodeSetup(passcode: passcode)
                    dismiss()
                } else {
                    showingError = true
                }
            } else {
                isConfirming = true
            }
        } else {
            if authService.authenticateWithPasscode(passcode) {
                dismiss()
            }
        }
    }
}

// Add a custom button style for better touch response
struct NumberPadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
} 
