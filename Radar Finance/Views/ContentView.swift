import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthenticationService()
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            IncomeView()
                .tabItem {
                    Label("Income", systemImage: "plus.circle.fill")
                }
            
            ExpenseView()
                .tabItem {
                    Label("Expenses", systemImage: "minus.circle.fill")
                }
            
            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(authService)
        .preferredColorScheme(.light)
        .dynamicTypeSize(.large)
    }
} 