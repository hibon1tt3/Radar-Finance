//
//  Radar_FinanceApp.swift
//  Radar Finance
//
//  Created by Theodore Tomita III on 12/30/24.
//

import SwiftUI
import SwiftData
import CloudKit

// Sync coordinator to handle all sync operations
@MainActor
final class SyncCoordinator {
    private let cloudKitService: CloudKitSyncService
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.cloudKitService = CloudKitSyncService.shared
        self.context = context
    }
    
    func performSync() async throws {
        // First setup subscriptions (doesn't use ModelContext)
        try await cloudKitService.setupSubscriptions()
        
        // Perform ModelContext operations on MainActor
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                do {
                    try await cloudKitService.syncData(context: self.context)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var isSyncing = false
    @Published var syncError: Error?
    @Published var lastSyncDate: Date?
    private var syncCoordinator: SyncCoordinator?
    
    func setupSyncCoordinator(with context: ModelContext) {
        syncCoordinator = SyncCoordinator(context: context)
    }
    
    func syncData() {
        guard let coordinator = syncCoordinator else { return }
        
        // Don't start a new sync if one is already in progress
        guard !isSyncing else { return }
        
        isSyncing = true
        print("Starting sync operation...")
        
        Task {
            do {
                try await coordinator.performSync()
                lastSyncDate = Date()
                print("Sync completed successfully")
            } catch {
                syncError = error
                print("Sync error: \(error)")
            }
            isSyncing = false
        }
    }
}

// Notification handler to manage CloudKit notifications
@MainActor
final class CloudKitNotificationHandler: NSObject {
    private let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitNotification),
            name: NSNotification.Name(rawValue: "com.apple.cloudkit.database.changes"),
            object: nil
        )
    }
    
    @objc private func handleCloudKitNotification() {
        appState.syncData()
    }
}

// App coordinator to manage app lifecycle and dependencies
@MainActor
final class AppCoordinator {
    let container: ModelContainer
    let appState: AppState
    private var notificationHandler: CloudKitNotificationHandler?
    
    init() async throws {
        let schema = Schema([
            Account.self,
            Transaction.self,
            Category.self,
            Schedule.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none  // Hybrid sync - disable SwiftData's CloudKit
        )
        
        container = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        appState = AppState()
        
        // Initialize CloudKit - this will handle default categories if needed
        try await CloudKitSyncService.shared.initialize(context: container.mainContext)
        
        // Register for remote notifications
        UIApplication.shared.registerForRemoteNotifications()
        
        // Setup initial state
        appState.setupSyncCoordinator(with: container.mainContext)
        notificationHandler = CloudKitNotificationHandler(appState: appState)
    }
}

@main
struct Radar_CheckbookApp: App {
    @StateObject private var authService = AuthenticationService()
    @State private var coordinator: AppCoordinator?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let coordinator = coordinator {
                    ParentView()
                        .modelContainer(coordinator.container)
                        .environmentObject(authService)
                        .environmentObject(coordinator.appState)
                        .preferredColorScheme(.light)
                        .onAppear {
                            coordinator.appState.syncData()
                        }
                } else {
                    ProgressView("Initializing...")
                        .task {
                            do {
                                coordinator = try await AppCoordinator()
                            } catch {
                                fatalError("Failed to initialize app: \(error)")
                            }
                        }
                }
            }
        }
    }
}
