import Foundation
import SwiftData

@Model
final class Account: Identifiable {
    var id: UUID
    var name: String
    var type: AccountType
    var balance: Decimal
    var icon: String
    var color: String
    var isDefault: Bool
    var startingBalance: Decimal
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]
    
    private static func sanitizeBalance(_ value: Decimal) -> Decimal {
        value.isNaN || value.isInfinite ? Decimal.zero : value
    }
    
    var safeBalance: Decimal {
        Self.sanitizeBalance(balance)
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        icon: String = "banknote",
        color: String = "#34C759",
        isDefault: Bool = false,
        startingBalance: Decimal = Decimal.zero
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = Self.sanitizeBalance(balance)
        self.icon = icon
        self.color = color
        self.isDefault = isDefault
        self.startingBalance = startingBalance
        self.transactions = []
    }
}

enum AccountType: String, Codable {
    case checking
    case savings
    case credit
    case investment
    case other
} 