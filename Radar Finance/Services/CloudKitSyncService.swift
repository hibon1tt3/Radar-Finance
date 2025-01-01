import CloudKit
import SwiftData

@MainActor
class CloudKitSyncService {
    static let shared = CloudKitSyncService()
    private let container: CKContainer
    private let database: CKDatabase
    private let requiredRecordTypes = ["Account", "Category", "Transaction"]
    
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
        // Ensure schema exists before attempting sync
        try await ensureSchemaExists()
        
        do {
            try await syncWithRetry(context: context)
        } catch let error as CloudKitSyncError {
            switch error {
            case .retryNeeded(let delay):
                try await Task.sleep(for: .seconds(delay))
                try await syncWithRetry(context: context)
            default:
                throw error
            }
        }
    }
    
    private func syncWithRetry(context: ModelContext) async throws {
        try await syncAccounts(context: context)
        try await syncCategories(context: context)
        try await syncTransactions(context: context)
    }
    
    private func syncAccounts(context: ModelContext) async throws {
        print("Starting account sync...")
        let descriptor = FetchDescriptor<Account>()
        let accounts = try context.fetch(descriptor)
        print("Found \(accounts.count) local accounts to sync")
        
        for account in accounts {
            // Create record with system-generated ID
            let record = CKRecord(recordType: "Account")
            // Store UUID as queryable field
            record["id"] = account.id.uuidString
            record["name"] = account.name
            record["type"] = account.type.rawValue
            record["balance"] = account.balance as NSDecimalNumber
            record["icon"] = account.icon
            record["color"] = account.color
            record["isDefault"] = account.isDefault
            record["startingBalance"] = account.startingBalance as NSDecimalNumber
            
            do {
                try await database.save(record)
                print("Successfully synced account: \(account.name)")
            } catch {
                print("Error syncing account \(account.name): \(error)")
                throw error
            }
        }
        print("Account sync completed")
    }
    
    private func syncCategories(context: ModelContext) async throws {
        print("Syncing categories to CloudKit...")
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { category in
                // Only sync non-system categories
                category.isSystem == false
            }
        )
        let categories = try context.fetch(descriptor)
        
        // Batch size of 5 categories at a time
        let batchSize = 5
        for batch in stride(from: 0, to: categories.count, by: batchSize) {
            let end = min(batch + batchSize, categories.count)
            let categoryBatch = Array(categories[batch..<end])
            
            for category in categoryBatch {
                let recordID = CKRecord.ID(recordName: category.id.uuidString)
                
                do {
                    let existingRecord = try await database.record(for: recordID)
                    existingRecord["name"] = category.name
                    existingRecord["type"] = category.type.rawValue
                    existingRecord["icon"] = category.icon
                    existingRecord["color"] = category.color
                    existingRecord["isSystem"] = false // Always false for synced categories
                    try await database.save(existingRecord)
                } catch let error as CKError where error.code == .unknownItem {
                    let record = CKRecord(recordType: "Category", recordID: recordID)
                    record["id"] = category.id.uuidString
                    record["name"] = category.name
                    record["type"] = category.type.rawValue
                    record["icon"] = category.icon
                    record["color"] = category.color
                    record["isSystem"] = false
                    try await database.save(record)
                }
                print("Synced custom category: \(category.name)")
            }
            
            if end < categories.count {
                try await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    private func syncTransactions(context: ModelContext) async throws {
        print("Syncing transactions to CloudKit...")
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)
        
        let batchSize = 5
        for batch in stride(from: 0, to: transactions.count, by: batchSize) {
            let end = min(batch + batchSize, transactions.count)
            let transactionBatch = Array(transactions[batch..<end])
            
            for transaction in transactionBatch {
                let recordID = CKRecord.ID(recordName: transaction.id.uuidString)
                
                do {
                    // Try to fetch existing record
                    let existingRecord = try await database.record(for: recordID)
                    // Update existing record
                    existingRecord["title"] = transaction.title
                    existingRecord["amount"] = transaction.amount as NSDecimalNumber
                    existingRecord["date"] = transaction.date
                    existingRecord["type"] = transaction.type.rawValue
                    existingRecord["notes"] = transaction.notes
                    existingRecord["status"] = transaction.status.rawValue
                    existingRecord["isEstimated"] = transaction.isEstimated
                    
                    // Update references
                    if let account = transaction.account {
                        let accountReference = CKRecord.Reference(
                            recordID: CKRecord.ID(recordName: account.id.uuidString),
                            action: .deleteSelf
                        )
                        existingRecord["accountRef"] = accountReference
                    }
                    
                    if let category = transaction.category {
                        let categoryReference = CKRecord.Reference(
                            recordID: CKRecord.ID(recordName: category.id.uuidString),
                            action: .deleteSelf
                        )
                        existingRecord["categoryRef"] = categoryReference
                    }
                    
                    try await database.save(existingRecord)
                } catch let error as CKError where error.code == .unknownItem {
                    // Record doesn't exist, create new one
                    let record = CKRecord(recordType: "Transaction", recordID: recordID)
                    record["id"] = transaction.id.uuidString
                    record["title"] = transaction.title
                    record["amount"] = transaction.amount as NSDecimalNumber
                    record["date"] = transaction.date
                    record["type"] = transaction.type.rawValue
                    record["notes"] = transaction.notes
                    record["status"] = transaction.status.rawValue
                    record["isEstimated"] = transaction.isEstimated
                    
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
                    
                    try await database.save(record)
                }
                print("Synced transaction: \(transaction.title)")
            }
            
            if end < transactions.count {
                try await Task.sleep(for: .milliseconds(500))
            }
        }
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
        print("Fetching accounts from CloudKit...")
        let query = CKQuery(
            recordType: "Account",
            // Use the id field for querying instead of recordName
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        
        let records = try await database.records(matching: query)
        print("Found \(records.matchResults.count) accounts in CloudKit")
        
        for record in try records.matchResults.map({ try $0.1.get() }) {
            if let idString = record["id"] as? String,
               let id = UUID(uuidString: idString) {
                let descriptor = FetchDescriptor<Account>(
                    predicate: #Predicate<Account> { account in
                        account.id == id
                    }
                )
                
                if let existingAccount = try context.fetch(descriptor).first {
                    print("Updating existing local account: \(existingAccount.name)")
                    existingAccount.name = record["name"] as! String
                    existingAccount.type = AccountType(rawValue: record["type"] as! String)!
                    existingAccount.balance = record["balance"] as! Decimal
                    existingAccount.icon = record["icon"] as! String
                    existingAccount.color = record["color"] as! String
                    existingAccount.isDefault = record["isDefault"] as! Bool
                    existingAccount.startingBalance = record["startingBalance"] as! Decimal
                } else {
                    print("Creating new local account from CloudKit: \(record["name"] as! String)")
                    let account = Account(
                        id: id,
                        name: record["name"] as! String,
                        type: AccountType(rawValue: record["type"] as! String)!,
                        balance: record["balance"] as! Decimal,
                        icon: record["icon"] as! String,
                        color: record["color"] as! String,
                        isDefault: record["isDefault"] as! Bool,
                        startingBalance: record["startingBalance"] as! Decimal
                    )
                    context.insert(account)
                }
            }
        }
        print("Account fetch completed")
    }
    
    private func fetchCategories(context: ModelContext) async throws {
        let query = CKQuery(
            recordType: "Category",
            predicate: NSPredicate(format: "id != %@ AND isSystem == false", "")
        )
        query.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        
        let records = try await database.records(matching: query)
        
        for record in try records.matchResults.map({ try $0.1.get() }) {
            let id = UUID(uuidString: record["id"] as! String)!
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
    
    private func fetchTransactions(context: ModelContext) async throws {
        let query = CKQuery(
            recordType: "Transaction",
            predicate: NSPredicate(format: "id != %@", "")
        )
        query.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        
        let records = try await database.records(matching: query)
        
        for record in try records.matchResults.map({ try $0.1.get() }) {
            let id = UUID(uuidString: record["id"] as! String)!
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { transaction in
                    transaction.id == id
                }
            )
            
            // Fetch related account and category
            var account: Account?
            var category: Category?
            
            if let accountRef = record["accountRef"] as? CKRecord.Reference {
                let accountId = UUID(uuidString: accountRef.recordID.recordName)!
                let accountDescriptor = FetchDescriptor<Account>(
                    predicate: #Predicate<Account> { a in
                        a.id == accountId
                    }
                )
                account = try context.fetch(accountDescriptor).first
            }
            
            if let categoryRef = record["categoryRef"] as? CKRecord.Reference {
                let categoryId = UUID(uuidString: categoryRef.recordID.recordName)!
                let categoryDescriptor = FetchDescriptor<Category>(
                    predicate: #Predicate<Category> { c in
                        c.id == categoryId
                    }
                )
                category = try context.fetch(categoryDescriptor).first
            }
            
            if let existingTransaction = try context.fetch(descriptor).first {
                // Update existing transaction
                existingTransaction.title = record["title"] as! String
                existingTransaction.amount = record["amount"] as! Decimal
                existingTransaction.isEstimated = record["isEstimated"] as! Bool
                existingTransaction.category = category
                existingTransaction.account = account
                existingTransaction.type = TransactionType(rawValue: record["type"] as! String)!
                existingTransaction.schedule = nil // Handle schedule separately if needed
                existingTransaction.status = TransactionStatus(rawValue: record["status"] as! String)!
                existingTransaction.date = record["date"] as! Date
                existingTransaction.notes = record["notes"] as? String
            } else {
                // Create new transaction with correct parameter order
                let transaction = Transaction(
                    id: id,
                    title: record["title"] as! String,
                    amount: record["amount"] as! Decimal,
                    isEstimated: record["isEstimated"] as! Bool,
                    category: category,
                    account: account,
                    type: TransactionType(rawValue: record["type"] as! String)!,
                    schedule: nil, // Handle schedule separately if needed
                    status: TransactionStatus(rawValue: record["status"] as! String)!,
                    date: record["date"] as! Date,
                    notes: record["notes"] as? String,
                    receiptImage: nil // Handle receipt image separately if needed
                )
                context.insert(transaction)
            }
        }
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
        case recordNotFound
        case invalidData
        case referenceError
        case networkError
        case serverRejected
        case retryNeeded(after: TimeInterval)
        case unknownError
        
        var localizedDescription: String {
            switch self {
            case .recordNotFound:
                return "The requested record could not be found."
            case .invalidData:
                return "The data is invalid or corrupted."
            case .referenceError:
                return "There was an error with the record reference."
            case .networkError:
                return "There was a problem connecting to iCloud. Please check your connection."
            case .serverRejected:
                return "Server rejected the request. Please try again later."
            case .retryNeeded(let seconds):
                return "Please wait \(Int(seconds)) seconds before trying again."
            case .unknownError:
                return "An unknown error occurred. Please try again."
            }
        }
    }
    
    private func handleCloudKitError(_ error: Error) -> CloudKitSyncError {
        switch error {
        case let ckError as CKError:
            switch ckError.code {
            case .serviceUnavailable, .networkUnavailable, .notAuthenticated:
                return .networkError
            case .unknownItem:
                return .recordNotFound
            case .serverRejectedRequest:
                // Add exponential backoff retry logic
                if let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? Double {
                    print("Server rejected request. Retry after \(retryAfter) seconds")
                    // You might want to implement retry logic here
                    return .retryNeeded(after: retryAfter)
                }
                return .serverRejected
            default:
                print("Unhandled CloudKit error: \(ckError.localizedDescription)")
                return .unknownError
            }
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
        accountRecord["balance"] = 0 as NSDecimalNumber
        accountRecord["icon"] = ""
        accountRecord["color"] = ""
        accountRecord["isDefault"] = false
        accountRecord["startingBalance"] = 0 as NSDecimalNumber
        
        let categoryRecord = CKRecord(recordType: "Category")
        categoryRecord["id"] = "" // This will be our queryable field
        categoryRecord["name"] = ""
        categoryRecord["type"] = ""
        categoryRecord["icon"] = ""
        categoryRecord["color"] = ""
        
        let transactionRecord = CKRecord(recordType: "Transaction")
        transactionRecord["id"] = "" // This will be our queryable field
        transactionRecord["title"] = ""
        transactionRecord["amount"] = 0 as NSDecimalNumber
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
            
            // Always ensure system categories exist
            CategoryService.createSystemCategories(in: context)
            
            let cloudCategories = try await fetchCloudKitCategories()
            
            if cloudCategories.isEmpty {
                print("No categories in CloudKit, syncing system categories...")
                try await syncAllData(context: context)
            } else {
                print("Found categories in CloudKit, fetching all data...")
                try await fetchAllData(context: context)
            }
            
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
} 
