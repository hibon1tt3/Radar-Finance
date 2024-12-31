import SwiftUI
import SwiftData

struct ParentView: View {
    @StateObject private var cameraManager = CameraPermissionManager()
    @StateObject private var authService = AuthenticationService()
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @State private var showingQuickTransactionSheet = false
    @State private var showingAddAccount = false
    
    var body: some View {
        Group {
            if !authService.isAuthenticated {
                LockScreenView()
            } else if accounts.isEmpty {
                NoAccountsView(showingAddAccount: $showingAddAccount)
                    .sheet(isPresented: $showingAddAccount) {
                        AddAccountView()
                    }
            } else {
                TabView {
                    NavigationStack {
                        DashboardView()
                    }
                    .tabItem {
                        Label("Dashboard", systemImage: "house.fill")
                    }
                    
                    NavigationStack {
                        IncomeView()
                    }
                    .tabItem {
                        Label("Income", systemImage: "arrow.down.circle.fill")
                    }
                    
                    NavigationStack {
                        ExpenseView()
                    }
                    .tabItem {
                        Label("Expenses", systemImage: "arrow.up.circle.fill")
                    }
                    
                    NavigationStack {
                        ReportsView()
                    }
                    .tabItem {
                        Label("Reports", systemImage: "chart.bar.fill")
                    }
                    
                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                }
                .onAppear {
                    cameraManager.checkInitialCameraPermission()
                }
            }
        }
        .environmentObject(authService)
        .environmentObject(cameraManager)
    }
} 