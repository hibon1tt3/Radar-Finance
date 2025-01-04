//
//  Radar_FinanceApp.swift
//  Radar Finance
//
//  Created by Theodore Tomita III on 12/30/24.
//

import SwiftUI
import SwiftData

@main
struct Radar_CheckbookApp: App {
    @StateObject private var authService = AuthenticationService()
    let container: ModelContainer
    
    var body: some Scene {
        WindowGroup {
            ParentView()
                .modelContainer(container)
                .environmentObject(authService)
                .preferredColorScheme(.light)
                .environment(\.sizeCategory, .medium)
                .dynamicTypeSize(.medium)
                .environment(\.legibilityWeight, .regular)
                .fontWeight(.regular)
        }
    }
    
    init() {
        UILabel.appearance().adjustsFontForContentSizeCategory = false
        UITextField.appearance().adjustsFontForContentSizeCategory = false
        UITextView.appearance().adjustsFontForContentSizeCategory = false
        
        let schema = Schema([
            Account.self,
            Transaction.self,
            Schedule.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer")
        }
    }
}
