import CloudKit
import SwiftData

@MainActor
class CloudKitSyncService {
    static let shared = CloudKitSyncService()
    private let container: CKContainer
    private let database: CKDatabase
    private let requiredRecordTypes = ["Account", "Category", "Transaction"]
    private let deletedRecordsKey = "DeletedRecordIDs"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.tomitatech.RadarFinance")
        database = container.privateCloudDatabase
    }
    
    // MARK: - Record Creation
    
    private func createRecord(from account: Account) -> CKRecord {
        let record = CKRecord(recordType: "Account")
        record["id"] = account.id.uuidString
        record["name"] = account.name
        record["type"] = account.type.rawValue
        record["balance"] = account.balance as NSDecimalNumber
        record["icon"] = account.icon
        record["color"] = account.color
        record["isDefault"] = account.isDefault
        record["startingBalance"] = account.startingBalance as NSDecimalNumber
        return record
    }
    
    private func createRecord(from transaction: Transaction) -> CKRecord {
        let record = CKRecord(recordType: "Transaction")
        record["id"] = transaction.id.uuidString
        record["title"] = transaction.title
        record["amount"] = transaction.amount as NSDecimalNumber
        record["date"] = transaction.date
        record["type"] = transaction.type.rawValue
        record["notes"] = transaction.notes
        record["status"] = transaction.status.rawValue
        record["isEstimated"] = transaction.isEstimated
        
        // References to related records
        if let account = transaction.account {
            let accountReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: account.id.uuidString),
                action: .deleteSelf
            )
            record["accountRef"] = accountReference
        }
        
        if let category = transaction.category {
            let categoryReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: category.id.uuidString),
                action: .deleteSelf
            )
            record["categoryRef"] = categoryReference
        }
        
        return record
    }
    
    private func createRecord(from category: Category) -> CKRecord {
        let record = CKRecord(recordType: "Category")
        record["id"] = category.id.uuidString
        record["name"] = category.name
        record["type"] = category.type.rawValue
        record["icon"] = category.icon
        record["color"] = category.color
        record["isSystem"] = category.isSystem
        return record
    }
    
    // MARK: - Sync Operations
    
    func syncAllData(context: ModelContext) async throws {
        print("Starting sync operation...")
        
        // First handle deletions
        try await syncDeletions()
        
        // Then sync remaining data
        try await syncWithRetry(context: context)
    }
    
    private func syncWithRetry(context: ModelContext) async throws {
        do {
            try await syncAccounts(context: context)
            try await syncCategories(context: context)
            try await syncTransactions(context: context)
        } catch let error as CKError {
            let syncError = handleCKError(error)
            switch syncError {
            case .retryNeeded(let delay):
                try await Task.sleep(for: .seconds(delay))
                try await syncWithRetry(context: context)
            case .networkError:
                print("Network error, will retry on next sync")
                throw syncError
            case .recordNotFound:
                print("Record not found, skipping")
            case .serverError:
                print("Server error, will retry on next sync")
                throw syncError
            case .deletionFailed:
                print("Deletion failed, will retry on next sync")
                throw syncError
            case .unknownError:
                print("Unknown error occurred")
                throw syncError
            }
        }
    }
    
    private func syncAccounts(context: ModelContext) async throws {
        print("Starting account sync...")
        let descriptor = FetchDescriptor<Account>()
        let accounts = try context.fetch(descriptor)
        print("Found \(accounts.count) local accounts to sync")
        
        for account in accounts {
            let recordID = CKRecord.ID(recordName: account.id.uuidString)
            
            do {
                // Try to fetch existing record first
                let existingRecord = try? await database.record(for: recordID)
                
                if let existingRecord = existingRecord {
                    // Update existing record
                    print("Updating existing record for account: \(account.name)")
                    existingRecord["name"] = account.name
                    existingRecord["type"] = account.type.rawValue
                    existingRecord["balance"] = NSNumber(value: Double(truncating: account.balance as NSNumber))
                    existingRecord["icon"] = account.icon
                    existingRecord["color"] = account.color
                    existingRecord["isDefault"] = account.isDefault
                    existingRecord["startingBalance"] = NSNumber(value: Double(truncating: account.startingBalance as NSNumber))
                    try await database.save(existingRecord)
                } else {
                    // Create new record with specific ID
                    print("Creating new record for account: \(account.name)")
                    let record = CKRecord(recordType: "Account", recordID: recordID)
                    record["id"] = account.id.uuidString
                    record["name"] = account.name
                    record["type"] = account.type.rawValue
                    record["balance"] = NSNumber(value: Double(truncating: account.balance as NSNumber))
                    record["icon"] = account.icon
                    record["color"] = account.color
                    record["isDefault"] = account.isDefault
                    record["startingBalance"] = NSNumber(value: Double(truncating: account.startingBalance as NSNumber))
                    try await database.save(record)
                }
                
                account.lastSyncDate = Date()
                print("Successfully synced account: \(account.name)")
                
            } catch {
                print("Error syncing account \(account.name): \(error)")
                if let ckError = error as? CKError {
                    switch ckError.code {
                    case .serverRecordChanged:
                        // Handle server record changed error
                        if let serverRecord = ckError.serverRecord {
                            print("Resolving conflict for account: \(account.name)")
                            try await handleServerRecordChanged(account: account, serverRecord: serverRecord)
                        }
                    default:
                        throw error
                    }
                } else {
                    throw error
                }
            }
        }
        print("Account sync completed")
    }
    
    private func syncCategories(context: ModelContext) async throws {
        print("Starting category sync...")
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { category in
                // Only sync non-system categories
                category.isSystem == false
            }
        )
        let categories = try context.fetch(descriptor)
        print("Found \(categories.count) local categories to sync")
        
        for category in categories {
            let recordID = CKRecord.ID(recordName: category.id.uuidString)
            
            do {
                // Try to fetch existing record first
                let existingRecord = try? await database.record(for: recordID)
                
                if let existingRecord = existingRecord {
                    // Update existing record
                    print("Updating existing record for category: \(category.name)")
                    existingRecord["name"] = category.name
                    existingRecord["type"] = category.type.rawValue
                    existingRecord["icon"] = category.icon
                    existingRecord["color"] = category.color
                    existingRecord["isSystem"] = category.isSystem
                    try await database.save(existingRecord)
                } else {
                    // Create new record with specific ID
                    print("Creating new record for category: \(category.name)")
                    let record = CKRecord(recordType: "Category", recordID: recordID)
                    record["id"] = category.id.uuidString
                    record["name"] = category.name
                    record["type"] = category.type.rawValue
                    record["icon"] = category.icon
                    record["color"] = category.color
                    record["isSystem"] = category.isSystem
                    try await database.save(record)
                }
                
                print("Successfully synced category: \(category.name)")
                
            } catch {
                print("Error syncing category \(category.name): \(error)")
                if let ckError = error as? CKError {
                    switch ckError.code {
                    case .serverRecordChanged:
                        // Handle server record changed error
                        if let serverRecord = ckError.serverRecord {
                            print("Resolving conflict for category: \(category.name)")
                            try await handleCategoryServerRecordChanged(category: category, serverRecord: serverRecord)
                        }
                    default:
                        throw error
                    }
                } else {
                    throw error
                }
            }
        }
        print("Category sync completed")
    }
    
    private func handleCategoryServerRecordChanged(category: Category, serverRecord: CKRecord) async throws {
        // Compare modification dates to determine which version to keep
        if let serverModDate = serverRecord.modificationDate,
           let localModDate = category.modificationDate {
            
            if localModDate > serverModDate {
                // Local changes are newer, update server record
                print("Local changes are newer, updating server record")
                let updatedRecord = CKRecord(recordType: "Category", recordID: serverRecord.recordID)
                updatedRecord["id"] = category.id.uuidString
                updatedRecord["name"] = category.name
                updatedRecord["type"] = category.type.rawValue
                updatedRecord["icon"] = category.icon
                updatedRecord["color"] = category.color
                updatedRecord["isSystem"] = category.isSystem
                try await database.save(updatedRecord)
            } else {
                // Server changes are newer, update local record
                print("Server changes are newer, updating local record")
                category.name = serverRecord["name"] as! String
                category.type = TransactionType(rawValue: serverRecord["type"] as! String)!
                category.icon = serverRecord["icon"] as! String
                category.color = serverRecord["color"] as! String
                category.isSystem = serverRecord["isSystem"] as! Bool
                category.modificationDate = serverRecord.modificationDate
            }
        }
    }
    
    private func syncTransactions(context: ModelContext) async throws {
        print("Starting transaction sync...")
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)
        print("Found \(transactions.count) local transactions to sync")
        
        for transaction in transactions {
            let recordID = CKRecord.ID(recordName: transaction.id.uuidString)
            
            do {
                // Try to fetch existing record first
                let existingRecord = try? await database.record(for: recordID)
                
                if let existingRecord = existingRecord {
                    // Update existing record
                    print("Updating existing record for transaction: \(transaction.title)")
                    existingRecord["title"] = transaction.title
                    existingRecord["amount"] = NSNumber(value: Double(truncating: transaction.amount as NSNumber))
                    existingRecord["date"] = transaction.date
                    existingRecord["type"] = transaction.type.rawValue
                    existingRecord["notes"] = transaction.notes
                    existingRecord["status"] = transaction.status.rawValue
                    existingRecord["isEstimated"] = transaction.isEstimated
                    
                    // Update references
                    if let account = transaction.account {
                        existingRecord["accountRef"] = CKRecord.Reference(
                            recordID: CKRecord.ID(recordName: account.id.uuidString),
                            action: .deleteSelf
                        )
                    }
                    
                    if let category = transaction.category {
                        existingRecord["categoryRef"] = CKRecord.Reference(
                            recordID: CKRecord.ID(recordName: category.id.uuidString),
                            action: .deleteSelf
                        )
                    }
                    
                    try await database.save(existingRecord)
                } else {
                    // Create new record with specific ID
                    print("Creating new record for transaction: \(transaction.title)")
                    let record = CKRecord(recordType: "Transaction", recordID: recordID)
                    record["id"] = transaction.id.uuidString
                    record["title"] = transaction.title
                    record["amount"] = NSNumber(value: Double(truncating: transaction.amount as NSNumber))
                    record["date"] = transaction.date
                    record["type"] = transaction.type.rawValue
                    record["notes"] = transaction.notes
                    record["status"] = transaction.status.rawValue
                    record["isEstimated"] = transaction.isEstimated
                    
                    // Add references
                    if let account = transaction.account {
                        record["accountRef"] = CKRecord.Reference(
                            recordID: CKRecord.ID(recordName: account.id.uuidString),
                            action: .deleteSelf
                        )
                    }
                    
                    if let category = transaction.category {
                        record["categoryRef"] = CKRecord.Reference(
                            recordID: CKRecord.ID(recordName: category.id.uuidString),
                            action: .deleteSelf
                        )
                    }
                    
                    try await database.save(record)
                }
                
                print("Successfully synced transaction: \(transaction.title)")
                
            } catch {
                print("Error syncing transaction \(transaction.title): \(error)")
                if let ckError = error as? CKError {
                    switch ckError.code {
                    case .serverRecordChanged:
                        // Handle server record changed error
                        if let serverRecord = ckError.serverRecord {
                            print("Resolving conflict for transaction: \(transaction.title)")
                            try await handleTransactionServerRecordChanged(
                                transaction: transaction, 
                                serverRecord: serverRecord,
                                context: context
                            )
                        }
                    default:
                        throw error
                    }
                } else {
                    throw error
                }
            }
        }
        print("Transaction sync completed")
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllData(context: ModelContext) async throws {
        // Ensure schema exists before attempting fetch
        try await ensureSchemaExists()
        
        try await fetchAccounts(context: context)
        try await fetchCategories(context: context)
        try await fetchTransactions(context: context)
    }
    
    private func fetchAccounts(context: ModelContext) async throws {
        let query = CKQuery(
            recordType: "Account",
            predicate: NSPredicate(format: "id != %@", "")
        )
        
        let records = try await database.records(matching: query)
        print("Found \(records.matchResults.count) accounts in CloudKit")
        
        for record in try records.matchResults.map({ try $0.1.get() }) {
            if let idString = record["id"] as? String {
                // Skip if this record was deleted locally
                if isDeleted("Account", withID: idString) {
                    print("Skipping deleted account: \(idString)")
                    continue
                }
                
                if let id = UUID(uuidString: idString) {
                    // Safely convert numbers to Decimal
                    let balance: Decimal
                    let startingBalance: Decimal
                    
                    if let balanceNumber = record["balance"] as? NSNumber {
                        balance = Decimal(string: balanceNumber.stringValue) ?? 0
                    } else {
                        balance = 0
                    }
                    
                    if let startingBalanceNumber = record["startingBalance"] as? NSNumber {
                        startingBalance = Decimal(string: startingBalanceNumber.stringValue) ?? 0
                    } else {
                        startingBalance = 0
                    }
                    
                    let descriptor = FetchDescriptor<Account>(
                        predicate: #Predicate<Account> { account in
                            account.id == id
                        }
                    )
                    
                    if let existingAccount = try context.fetch(descriptor).first {
                        print("Updating existing local account: \(existingAccount.name)")
                        existingAccount.name = record["name"] as! String
                        existingAccount.type = AccountType(rawValue: record["type"] as! String)!
                        existingAccount.balance = balance
                        existingAccount.icon = record["icon"] as! String
                        existingAccount.color = record["color"] as! String
                        existingAccount.isDefault = record["isDefault"] as! Bool
                        existingAccount.startingBalance = startingBalance
                        existingAccount.lastSyncDate = record.modificationDate
                    } else {
                        print("Creating new local account from CloudKit: \(record["name"] as! String)")
                        let account = Account(
                            id: id,
                            name: record["name"] as! String,
                            type: AccountType(rawValue: record["type"] as! String)!,
                            balance: balance,
                            icon: record["icon"] as! String,
                            color: record["color"] as! String,
                            isDefault: record["isDefault"] as! Bool,
                            startingBalance: startingBalance
                        )
                        account.lastSyncDate = record.modificationDate
                        context.insert(account)
                    }
                }
            }
        }
        print("Account fetch completed")
    }
    
    private func fetchCategories(context: ModelContext) async throws {
        let query = CKQuery(
            recordType: "Category",
            predicate: NSPredicate(format: "id != %@", "")
        )
        
        let records = try await database.records(matching: query)
        print("Found \(records.matchResults.count) categories in CloudKit")
        
        for record in try records.matchResults.map({ try $0.1.get() }) {
            if let idString = record["id"] as? String {
                // Skip if this record was deleted locally
                if isDeleted("Category", withID: idString) {
                    print("Skipping deleted category: \(idString)")
                    continue
                }
                
                if let id = UUID(uuidString: idString) {
                    let descriptor = FetchDescriptor<Category>(
                        predicate: #Predicate<Category> { category in
                            category.id == id
                        }
                    )
                    
                    if let existingCategory = try context.fetch(descriptor).first {
                        // Update existing custom category
                        existingCategory.name = record["name"] as! String
                        existingCategory.type = TransactionType(rawValue: record["type"] as! String)!
                        existingCategory.icon = record["icon"] as! String
                        existingCategory.color = record["color"] as! String
                    } else {
                        // Create new custom category
                        let category = Category(
                            id: id,
                            name: record["name"] as! String,
                            type: TransactionType(rawValue: record["type"] as! String)!,
                            icon: record["icon"] as! String,
                            color: record["color"] as! String,
                            isSystem: false // Always false for fetched categories
                        )
                        context.insert(category)
                    }
                }
            }
        }
    }
    
    private func fetchTransactions(context: ModelContext) async throws {
        let query = CKQuery(
            recordType: "Transaction",
            predicate: NSPredicate(format: "id != %@", "")
        )
        
        let records = try await database.records(matching: query)
        print("Found \(records.matchResults.count) transactions in CloudKit")
        
        for record in try records.matchResults.map({ try $0.1.get() }) {
            if let idString = record["id"] as? String {
                // Skip if this record was deleted locally
                if isDeleted("Transaction", withID: idString) {
                    print("Skipping deleted transaction: \(idString)")
                    continue
                }
                
                if let id = UUID(uuidString: idString) {
                    // Safely convert amount to Decimal
                    let amount: Decimal
                    if let amountNumber = record["amount"] as? NSNumber {
                        amount = Decimal(string: amountNumber.stringValue) ?? 0
                    } else {
                        amount = 0
                    }
                    
                    // Use simple id comparison
                    let descriptor = FetchDescriptor<Transaction>(
                        predicate: #Predicate<Transaction> { transaction in
                            transaction.id == id
                        }
                    )
                    
                    if let existingTransaction = try context.fetch(descriptor).first {
                        print("Updating existing transaction: \(existingTransaction.title)")
                        existingTransaction.title = record["title"] as! String
                        existingTransaction.amount = amount
                        existingTransaction.date = record["date"] as! Date
                        existingTransaction.type = TransactionType(rawValue: record["type"] as! String)!
                        existingTransaction.notes = record["notes"] as? String
                        existingTransaction.status = TransactionStatus(rawValue: record["status"] as! String)!
                        existingTransaction.isEstimated = record["isEstimated"] as! Bool
                        
                        // Handle references
                        if let accountRef = record["accountRef"] as? CKRecord.Reference {
                            let recordID = UUID(uuidString: accountRef.recordID.recordName)!
                            let accountDescriptor = FetchDescriptor<Account>(
                                predicate: #Predicate<Account> { account in
                                    account.id == recordID
                                }
                            )
                            existingTransaction.account = try context.fetch(accountDescriptor).first
                        }
                        
                        if let categoryRef = record["categoryRef"] as? CKRecord.Reference {
                            let recordID = UUID(uuidString: categoryRef.recordID.recordName)!
                            let categoryDescriptor = FetchDescriptor<Category>(
                                predicate: #Predicate<Category> { category in
                                    category.id == recordID
                                }
                            )
                            existingTransaction.category = try context.fetch(categoryDescriptor).first
                        }
                    } else {
                        print("Creating new transaction from CloudKit: \(record["title"] as! String)")
                        let transaction = Transaction(
                            id: id,
                            title: record["title"] as! String,
                            amount: amount,
                            isEstimated: record["isEstimated"] as! Bool,
                            category: nil,
                            account: nil,
                            type: TransactionType(rawValue: record["type"] as! String)!,
                            schedule: nil,
                            status: TransactionStatus(rawValue: record["status"] as! String)!,
                            date: record["date"] as! Date,
                            notes: record["notes"] as? String,
                            receiptImage: nil
                        )
                        
                        // Handle references
                        if let accountRef = record["accountRef"] as? CKRecord.Reference {
                            let recordID = UUID(uuidString: accountRef.recordID.recordName)!
                            let accountDescriptor = FetchDescriptor<Account>(
                                predicate: #Predicate<Account> { account in
                                    account.id == recordID
                                }
                            )
                            transaction.account = try context.fetch(accountDescriptor).first
                        }
                        
                        if let categoryRef = record["categoryRef"] as? CKRecord.Reference {
                            let recordID = UUID(uuidString: categoryRef.recordID.recordName)!
                            let categoryDescriptor = FetchDescriptor<Category>(
                                predicate: #Predicate<Category> { category in
                                    category.id == recordID
                                }
                            )
                            transaction.category = try context.fetch(categoryDescriptor).first
                        }
                        
                        context.insert(transaction)
                    }
                }
            }
        }
        print("Transaction fetch completed")
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflicts(localRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
        // Compare modification dates
        if let localDate = localRecord.modificationDate,
           let serverDate = serverRecord.modificationDate {
            // Use the most recent version
            return localDate > serverDate ? localRecord : serverRecord
        }
        // If dates can't be compared, prefer server version
        return serverRecord
    }
    
    // MARK: - CloudKit Subscriptions
    
    func setupSubscriptions() async throws {
        // Account subscription
        let accountSubscription = CKQuerySubscription(
            recordType: "Account",
            predicate: NSPredicate(value: true),
            subscriptionID: "account-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        accountSubscription.notificationInfo = notification
        
        try await database.save(accountSubscription)
        
        // Category subscription
        let categorySubscription = CKQuerySubscription(
            recordType: "Category",
            predicate: NSPredicate(value: true),
            subscriptionID: "category-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        categorySubscription.notificationInfo = notification
        try await database.save(categorySubscription)
        
        // Transaction subscription
        let transactionSubscription = CKQuerySubscription(
            recordType: "Transaction",
            predicate: NSPredicate(value: true),
            subscriptionID: "transaction-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        transactionSubscription.notificationInfo = notification
        try await database.save(transactionSubscription)
    }
    
    // MARK: - Error Handling
    
    enum CloudKitSyncError: Error {
        case deletionFailed
        case retryNeeded(delay: TimeInterval)
        case unknownError
        case networkError
        case serverError
        case recordNotFound
    }
    
    private func handleCKError(_ error: CKError) -> CloudKitSyncError {
        switch error.code {
        case .networkFailure, .networkUnavailable, .serverResponseLost, .serviceUnavailable:
            return .networkError
        case .unknownItem:
            return .recordNotFound
        case .serverRecordChanged:
            return .serverError
        case .quotaExceeded, .limitExceeded:
            return .retryNeeded(delay: 60)
        case .zoneBusy, .requestRateLimited:
            let retryAfter = error.retryAfterSeconds ?? 3
            return .retryNeeded(delay: retryAfter)
        default:
            return .unknownError
        }
    }
    
    func performCleanSync(context: ModelContext) async throws {
        // Delete all existing CloudKit records
        try await deleteAllRecords()
        
        // Reset subscriptions
        try await setupSubscriptions()
        
        // Sync all local data
        try await syncAllData(context: context)
    }
    
    private func deleteAllRecords() async throws {
        let recordTypes = ["Account", "Category", "Transaction"]
        
        for recordType in recordTypes {
            let query = CKQuery(
                recordType: recordType,
                predicate: NSPredicate(format: "id != %@", "")
            )
            let records = try await database.records(matching: query)
            
            for record in try records.matchResults.map({ try $0.1.get() }) {
                try await database.deleteRecord(withID: record.recordID)
            }
        }
    }
    
    private func ensureSchemaExists() async throws {
        do {
            let query = CKQuery(
                recordType: "Account",
                predicate: NSPredicate(format: "id != %@", "")
            )
            let result = try await database.records(matching: query)
            if result.matchResults.isEmpty {
                // Schema exists but no data
                print("Schema exists but no data found")
            }
        } catch let error as CKError where error.code == .unknownItem {
            print("Schema not found, creating...")
            try await createSchema()
        } catch {
            print("Error checking schema: \(error)")
            throw error
        }
    }
    
    private func createSchema() async throws {
        print("Creating CloudKit schema...")
        
        // Create schema records with indexed fields
        let accountRecord = CKRecord(recordType: "Account")
        accountRecord["id"] = "" // This will be our queryable field
        accountRecord["name"] = ""
        accountRecord["type"] = ""
        accountRecord["balance"] = 0.0 // Change to Double for CloudKit
        accountRecord["icon"] = ""
        accountRecord["color"] = ""
        accountRecord["isDefault"] = false
        accountRecord["startingBalance"] = 0.0 // Change to Double for CloudKit
        
        let categoryRecord = CKRecord(recordType: "Category")
        categoryRecord["id"] = "" // This will be our queryable field
        categoryRecord["name"] = ""
        categoryRecord["type"] = ""
        categoryRecord["icon"] = ""
        categoryRecord["color"] = ""
        categoryRecord["isSystem"] = false  // Add isSystem field
        
        let transactionRecord = CKRecord(recordType: "Transaction")
        transactionRecord["id"] = "" // This will be our queryable field
        transactionRecord["title"] = ""
        transactionRecord["amount"] = 0.0 // Change to Double for CloudKit
        transactionRecord["date"] = Date()
        transactionRecord["type"] = ""
        transactionRecord["notes"] = ""
        transactionRecord["status"] = ""
        transactionRecord["isEstimated"] = false
        transactionRecord["accountRef"] = nil as CKRecord.Reference?
        transactionRecord["categoryRef"] = nil as CKRecord.Reference?
        
        // Save schema records
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try await self.database.save(accountRecord)
            }
            group.addTask {
                _ = try await self.database.save(categoryRecord)
            }
            group.addTask {
                _ = try await self.database.save(transactionRecord)
            }
            try await group.waitForAll()
        }
        
        // Clean up schema records
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.database.deleteRecord(withID: accountRecord.recordID)
            }
            group.addTask {
                try await self.database.deleteRecord(withID: categoryRecord.recordID)
            }
            group.addTask {
                try await self.database.deleteRecord(withID: transactionRecord.recordID)
            }
            try await group.waitForAll()
        }
        
        print("CloudKit schema created successfully")
    }
    
    // Add a public method to initialize CloudKit
    func initialize(context: ModelContext) async throws {
        print("Initializing CloudKit...")
        
        do {
            try await ensureSchemaExists()
            
            // First sync deletions
            try await syncDeletions()
            
            // Then fetch existing data
            print("Fetching existing data from CloudKit...")
            try await fetchAllData(context: context)
            
            // Ensure system categories exist
            CategoryService.createSystemCategories(in: context)
            
            // Finally sync any new local changes
            try await syncAllData(context: context)
            
        } catch let error as CKError where error.code == .unknownItem {
            print("Schema not found, creating...")
            try await createSchema()
            
            print("Creating system categories...")
            CategoryService.createSystemCategories(in: context)
            try await syncAllData(context: context)
        } catch {
            print("Error during initialization: \(error)")
            throw error
        }
        
        try await setupSubscriptions()
        print("CloudKit initialization complete")
    }
    
    // Add a helper method to check for existing categories in CloudKit
    private func fetchCloudKitCategories() async throws -> [CKRecord] {
        let query = CKQuery(
            recordType: "Category",
            predicate: NSPredicate(format: "id != %@", "")
        )
        let records = try await database.records(matching: query)
        return try records.matchResults.map { try $0.1.get() }
    }
    
    // Update syncData to include context parameter
    func syncData(context: ModelContext) async throws {
        print("Starting sync operation...")
        
        // Only sync if there are actual changes
        let hasChanges = try await checkForChanges(context: context)
        
        if hasChanges {
            try await syncAllData(context: context)
            print("Sync completed with changes")
        } else {
            print("No changes to sync")
        }
    }
    
    // Update checkForChanges to accept context parameter
    private func checkForChanges(context: ModelContext) async throws -> Bool {
        // Implement logic to check if local data differs from CloudKit data
        let query = CKQuery(
            recordType: "Category",
            predicate: NSPredicate(format: "id != %@", "")
        )
        let records = try await database.records(matching: query)
        let cloudRecords = try records.matchResults.map { try $0.1.get() }
        let cloudCount = cloudRecords.count
        
        let categoryDescriptor = FetchDescriptor<Category>()
        let localCount = try context.fetch(categoryDescriptor).count
        
        // If counts differ, we definitely have changes
        if cloudCount != localCount {
            return true
        }
        
        // If counts are same, check for content differences
        let localCategories = try context.fetch(categoryDescriptor)
        let cloudIds = Set(cloudRecords.map { $0["id"] as! String })
        let localIds = Set(localCategories.map { $0.id.uuidString })
        
        // Return true if there are any differences in IDs
        return cloudIds != localIds
    }
    
    private func handleServerRecordChanged(account: Account, serverRecord: CKRecord) async throws {
        // Compare modification dates to determine which version to keep
        if let serverModDate = serverRecord.modificationDate,
           let localModDate = account.modificationDate {
            
            if localModDate > serverModDate {
                // Local changes are newer, update server record
                print("Local changes are newer, updating server record")
                let updatedRecord = CKRecord(recordType: "Account", recordID: serverRecord.recordID)
                updatedRecord["id"] = account.id.uuidString
                updatedRecord["name"] = account.name
                updatedRecord["type"] = account.type.rawValue
                updatedRecord["balance"] = account.balance.description
                updatedRecord["icon"] = account.icon
                updatedRecord["color"] = account.color
                updatedRecord["isDefault"] = account.isDefault
                updatedRecord["startingBalance"] = account.startingBalance.description
                try await database.save(updatedRecord)
            } else {
                // Server changes are newer, update local record
                print("Server changes are newer, updating local record")
                if let balanceString = serverRecord["balance"] as? String,
                   let balance = Decimal(string: balanceString),
                   let startingBalanceString = serverRecord["startingBalance"] as? String,
                   let startingBalance = Decimal(string: startingBalanceString) {
                    account.name = serverRecord["name"] as! String
                    account.type = AccountType(rawValue: serverRecord["type"] as! String)!
                    account.balance = balance
                    account.icon = serverRecord["icon"] as! String
                    account.color = serverRecord["color"] as! String
                    account.isDefault = serverRecord["isDefault"] as! Bool
                    account.startingBalance = startingBalance
                    account.modificationDate = serverRecord.modificationDate
                }
            }
        }
        
        account.lastSyncDate = Date()
    }
    
    private func handleTransactionServerRecordChanged(transaction: Transaction, serverRecord: CKRecord, context: ModelContext) async throws {
        // Compare modification dates to determine which version to keep
        if let serverModDate = serverRecord.modificationDate,
           let localModDate = transaction.modificationDate {
            
            if localModDate > serverModDate {
                // Local changes are newer, update server record
                print("Local changes are newer, updating server record")
                let updatedRecord = CKRecord(recordType: "Transaction", recordID: serverRecord.recordID)
                updatedRecord["id"] = transaction.id.uuidString
                updatedRecord["title"] = transaction.title
                updatedRecord["amount"] = NSNumber(value: Double(truncating: transaction.amount as NSNumber))
                updatedRecord["date"] = transaction.date
                updatedRecord["type"] = transaction.type.rawValue
                updatedRecord["notes"] = transaction.notes
                updatedRecord["status"] = transaction.status.rawValue
                updatedRecord["isEstimated"] = transaction.isEstimated
                
                // Add references
                if let account = transaction.account {
                    updatedRecord["accountRef"] = CKRecord.Reference(
                        recordID: CKRecord.ID(recordName: account.id.uuidString),
                        action: .deleteSelf
                    )
                }
                
                if let category = transaction.category {
                    updatedRecord["categoryRef"] = CKRecord.Reference(
                        recordID: CKRecord.ID(recordName: category.id.uuidString),
                        action: .deleteSelf
                    )
                }
                
                try await database.save(updatedRecord)
            } else {
                // Server changes are newer, update local record
                print("Server changes are newer, updating local record")
                if let amountNumber = serverRecord["amount"] as? NSNumber {
                    let amount = Decimal(string: amountNumber.stringValue) ?? 0
                    
                    transaction.title = serverRecord["title"] as! String
                    transaction.amount = amount
                    transaction.date = serverRecord["date"] as! Date
                    transaction.type = TransactionType(rawValue: serverRecord["type"] as! String)!
                    transaction.notes = serverRecord["notes"] as? String
                    transaction.status = TransactionStatus(rawValue: serverRecord["status"] as! String)!
                    transaction.isEstimated = serverRecord["isEstimated"] as! Bool
                    transaction.modificationDate = serverRecord.modificationDate
                    
                    // Handle references
                    if let accountRef = serverRecord["accountRef"] as? CKRecord.Reference {
                        let recordID = UUID(uuidString: accountRef.recordID.recordName)!
                        let accountDescriptor = FetchDescriptor<Account>(
                            predicate: #Predicate<Account> { account in
                                account.id == recordID
                            }
                        )
                        transaction.account = try context.fetch(accountDescriptor).first
                    }
                    
                    if let categoryRef = serverRecord["categoryRef"] as? CKRecord.Reference {
                        let recordID = UUID(uuidString: categoryRef.recordID.recordName)!
                        let categoryDescriptor = FetchDescriptor<Category>(
                            predicate: #Predicate<Category> { category in
                                category.id == recordID
                            }
                        )
                        transaction.category = try context.fetch(categoryDescriptor).first
                    }
                }
            }
        }
        
        transaction.lastSyncDate = Date()
    }
    
    func deleteRecord(_ type: String, withID id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        
        do {
            try await database.deleteRecord(withID: recordID)
            markAsDeleted(type, withID: id)
            print("Successfully deleted CloudKit record: \(id.uuidString)")
        } catch let error as CKError where error.code == .unknownItem {
            // Still mark as deleted locally even if it doesn't exist in CloudKit
            markAsDeleted(type, withID: id)
            print("Record already deleted or doesn't exist in CloudKit: \(id.uuidString)")
        } catch {
            print("Error deleting CloudKit record: \(error)")
            throw error
        }
    }
    
    func handleModelDeletion<T: Identifiable>(_ object: T) async throws -> Bool where T.ID == UUID {
        let id = object.id
        let type: String
        
        switch object {
        case is Account:
            type = "Account"
        case is Transaction:
            type = "Transaction"
        case is Category:
            type = "Category"
        default:
            type = "Unknown"
        }
        
        print("Attempting to delete \(type) with ID: \(id.uuidString)")
        
        // First try to delete from CloudKit
        let recordID = CKRecord.ID(recordName: id.uuidString)
        do {
            try await database.deleteRecord(withID: recordID)
            print("Successfully deleted \(type) from CloudKit: \(id.uuidString)")
            
            // Remove from pending deletions if it was there
            removeFromDeletedRecords(type: type, id: id.uuidString)
            return true
        } catch let error as CKError {
            switch error.code {
            case .unknownItem:
                print("\(type) already deleted from CloudKit: \(id.uuidString)")
                return true
            case .networkFailure, .networkUnavailable, .serverResponseLost, .serviceUnavailable:
                print("Network error while deleting \(type): \(error)")
                // Mark for later deletion
                markAsDeleted(type, withID: id)
                throw error
            default:
                print("Error deleting \(type) from CloudKit: \(error)")
                markAsDeleted(type, withID: id)
                throw error
            }
        }
    }
    
    // Add method to remove specific record from deleted records
    private func removeFromDeletedRecords(type: String, id: String) {
        print("Removing \(type) with ID \(id) from deletion tracking")
        var deletions = getDeletedRecords()
        deletions.removeAll { $0.recordID == id }
        
        if deletions.isEmpty {
            userDefaults.removeObject(forKey: deletedRecordsKey)
        } else {
            if let encoded = try? JSONEncoder().encode(deletions) {
                userDefaults.set(encoded, forKey: deletedRecordsKey)
            }
        }
        userDefaults.synchronize()
    }
    
    // Update markAsDeleted to prevent duplicates
    private func markAsDeleted(_ type: String, withID id: UUID) {
        print("Marking \(type) with ID \(id.uuidString) for deletion")
        let deletion = DeletionRecord(
            recordID: id.uuidString,
            recordType: type,
            deletionDate: Date()
        )
        
        var deletions = getDeletedRecords()
        // Remove any existing deletion record for this ID
        deletions.removeAll { $0.recordID == id.uuidString }
        deletions.append(deletion)
        
        if let encoded = try? JSONEncoder().encode(deletions) {
            userDefaults.set(encoded, forKey: deletedRecordsKey)
            userDefaults.synchronize()
        }
    }
    
    // Add a struct to store deletion info
    private struct DeletionRecord: Codable {
        let recordID: String
        let recordType: String
        let deletionDate: Date
    }
    
    // Add methods to manage deleted records
    private func getDeletedRecords() -> [DeletionRecord] {
        guard let data = userDefaults.data(forKey: deletedRecordsKey),
              let deletions = try? JSONDecoder().decode([DeletionRecord].self, from: data) else {
            return []
        }
        return deletions
    }
    
    private func isDeleted(_ type: String, withID id: String) -> Bool {
        let deletions = getDeletedRecords()
        return deletions.contains { $0.recordID == id && $0.recordType == type }
    }
    
    // Add method to clear synced deletions
    private func clearSyncedDeletions() {
        userDefaults.removeObject(forKey: deletedRecordsKey)
        userDefaults.synchronize()
    }
    
    // Update syncDeletions to clear records after successful sync
    private func syncDeletions() async throws {
        let deletedRecords = getDeletedRecords()
        print("Starting deletion sync for \(deletedRecords.count) records")
        
        for deletion in deletedRecords {
            let recordID = CKRecord.ID(recordName: deletion.recordID)
            print("Attempting to delete record: \(deletion.recordID) of type: \(deletion.recordType)")
            
            do {
                try await database.deleteRecord(withID: recordID)
                print("Successfully deleted record: \(deletion.recordID)")
                removeFromDeletedRecords(type: deletion.recordType, id: deletion.recordID)
            } catch let error as CKError where error.code == .unknownItem {
                print("Record already deleted: \(deletion.recordID)")
                removeFromDeletedRecords(type: deletion.recordType, id: deletion.recordID)
            } catch {
                print("Failed to delete record \(deletion.recordID): \(error)")
                throw error
            }
        }
    }
} 
