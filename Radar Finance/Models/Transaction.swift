import Foundation
import SwiftData

@Model
final class Transaction: Identifiable {
    var id: UUID
    var title: String
    var amount: Decimal
    var isEstimated: Bool
    var type: TransactionType
    var status: TransactionStatus
    var date: Date
    var notes: String?
    
    @Relationship(deleteRule: .nullify) var category: Category?
    @Relationship(deleteRule: .nullify) var account: Account?
    @Relationship(deleteRule: .cascade) var schedule: Schedule?
    
    @Attribute(.externalStorage) var receiptImage: Data?
    
    var safeAmount: Decimal {
        if amount.isNaN || amount.isInfinite {
            return Decimal.zero
        }
        return amount
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        isEstimated: Bool = false,
        category: Category? = nil,
        account: Account? = nil,
        type: TransactionType,
        schedule: Schedule? = nil,
        status: TransactionStatus = .pending,
        date: Date = Date(),
        notes: String? = nil,
        receiptImage: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount.isNaN || amount.isInfinite ? Decimal.zero : amount
        self.isEstimated = isEstimated
        self.category = category
        self.account = account
        self.type = type
        self.schedule = schedule
        self.status = status
        self.date = date
        self.notes = notes
        self.receiptImage = receiptImage
    }
    
    var nextOccurrence: Date? {
        guard let schedule = schedule else { return nil }
        
        let startDate = Date().startOfDay
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        
        return DateHelper.generateOccurrences(
            for: schedule,
            startingFrom: startDate,
            endDate: endDate
        ).first
    }
    
    func generateUpcomingOccurrences() -> [TransactionOccurrence] {
        guard let schedule = schedule else { return [] }
        
        let startDate = Date().startOfDay
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        
        return DateHelper.generateOccurrences(
            for: schedule,
            startingFrom: startDate,
            endDate: endDate
        ).map { date in
            TransactionOccurrence(
                transaction: self,
                dueDate: date,
                amount: amount
            )
        }
    }
    
    func generateOccurrencesForMonth() -> [TransactionOccurrence] {
        guard let schedule = schedule else { return [] }
        
        let startDate = Date().startOfMonth
        let endDate = Date().endOfMonth
        
        return DateHelper.generateOccurrences(
            for: schedule,
            startingFrom: startDate,
            endDate: endDate
        ).map { date in
            TransactionOccurrence(
                transaction: self,
                dueDate: date,
                amount: amount
            )
        }
    }
    
    var completedOccurrences: Set<Date> {
        get {
            if let data = UserDefaults.standard.data(forKey: "completed_\(id.uuidString)"),
               let dates = try? JSONDecoder().decode(Set<Date>.self, from: data) {
                return dates
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "completed_\(id.uuidString)")
            }
        }
    }
}

enum TransactionType: String, Codable {
    case income
    case expense
}

enum TransactionStatus: String, Codable {
    case pending
    case completed
    case cancelled
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
    
    var endOfMonth: Date {
        if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) {
            return Calendar.current.date(byAdding: .day, value: -1, to: nextMonth) ?? self
        }
        return self
    }
} 