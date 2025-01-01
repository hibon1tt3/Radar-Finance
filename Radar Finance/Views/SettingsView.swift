import SwiftUI
import SwiftData

enum SettingsTab {
    case accounts
    case categories
    case security
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingResetAlert = false
    @State private var showingResetConfirmation = false
    @AppStorage("useBiometricAuth") private var useBiometricAuth = false
    @EnvironmentObject private var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cameraManager: CameraPermissionManager
    @EnvironmentObject private var viewModel: AppState
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    var selectedTab: SettingsTab = .accounts
    @State private var isSyncing = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Manage") {
                    NavigationLink("Accounts", destination: AccountListView())
                        .tag(SettingsTab.accounts)
                    NavigationLink("Categories", destination: CategoryListView())
                        .tag(SettingsTab.categories)
                }
                
                Section("Security") {
                    Toggle("Use Face ID", isOn: Binding(
                        get: { useBiometricAuth },
                        set: { newValue in
                            if newValue {
                                authService.toggleBiometricAuth(enabled: true)
                            } else {
                                authService.toggleBiometricAuth(enabled: false)
                            }
                        }
                    ))
                    
                    if authService.hasPasscode() {
                        Button("Change Passcode") {
                            authService.showingPasscodeSetup = true
                        }
                    }
                }
                
                Section("Features") {
                    Toggle("Receipt Photos", isOn: Binding(
                        get: { cameraManager.isCameraEnabled },
                        set: { newValue in
                            if newValue {
                                cameraManager.requestCameraAccess()
                            } else {
                                cameraManager.disableCamera()
                            }
                        }
                    ))
                }
                
                Section("Data") {
                    Button("Export Data") {
                        // Export functionality to be implemented
                    }
                    
                    Button("Reset App Data", role: .destructive) {
                        showingResetAlert = true
                    }
                }
                
                Section("Sync") {
                    Button(action: {
                        isSyncing = true
                        viewModel.syncData()
                    }) {
                        HStack {
                            Text("Sync Now")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isSyncing)
                    
                    if let lastSync = viewModel.lastSyncDate {
                        HStack {
                            Text("Last Synced")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset App Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    showingResetConfirmation = true
                }
            } message: {
                Text("Are you sure you want to reset all app data? This will delete all accounts, transactions, and categories. This action cannot be undone.")
            }
            .sheet(isPresented: .init(
                get: { authService.showingPasscodeSetup },
                set: { show in
                    authService.showingPasscodeSetup = show
                    if !show && !authService.hasPasscode() {
                        useBiometricAuth = false // Reset toggle if passcode setup was cancelled
                    }
                }
            )) {
                PasscodeEntryView(isSetup: true)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingResetConfirmation) {
                DeleteConfirmationView(
                    isPresented: $showingResetConfirmation,
                    title: "Confirm Reset",
                    message: "This will permanently delete all your accounts, transactions, and categories. This action cannot be undone.",
                    onConfirm: {
                        resetAppData()
                        dismiss()
                    }
                )
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onChange(of: viewModel.isSyncing) { _, newValue in
                isSyncing = newValue
            }
        }
    }
    
    private func resetAppData() {
        // Delete all transactions
        try? modelContext.delete(model: Transaction.self)
        
        // Delete all accounts
        try? modelContext.delete(model: Account.self)
        
        // Delete all categories
        try? modelContext.delete(model: Category.self)
        
        // Save changes
        try? modelContext.save()
        
        // Recreate system categories
        CategoryService.createSystemCategories(in: modelContext)
        
        // Dismiss to return to onboarding
        dismiss()
    }
    
    private func resetCategories() {
        // Delete all existing categories
        let descriptor = FetchDescriptor<Category>()
        if let categories = try? modelContext.fetch(descriptor) {
            for category in categories {
                modelContext.delete(category)
            }
        }
        
        // Create system categories
        CategoryService.createSystemCategories(in: modelContext)
        try? modelContext.save()
        
        // Show success message
        showingAlert = true
        alertTitle = "Success"
        alertMessage = "Categories have been reset to defaults."
    }
} 