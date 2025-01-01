import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var type: TransactionType
    var icon: String
    var color: String
    var isSystem: Bool  // New property to identify system categories
    var modificationDate: Date? // Add this property
    
    init(
        id: UUID = UUID(),
        name: String,
        type: TransactionType,
        icon: String,
        color: String,
        isSystem: Bool = false  // Default to false for custom categories
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.color = color
        self.isSystem = isSystem
        self.modificationDate = Date() // Set initial modification date
    }
}

// Add system category identifiers
extension Category {
    static let systemCategories: [SystemCategory] = [
        // Income categories
        .init(name: "Salary", type: .income, icon: "dollarsign.circle.fill", color: "systemGreen"),
        .init(name: "Freelance", type: .income, icon: "briefcase.fill", color: "systemBlue"),
        .init(name: "Investments", type: .income, icon: "chart.line.uptrend.xyaxis", color: "systemPurple"),
        .init(name: "Reimbursement", type: .income, icon: "arrow.clockwise", color: "systemOrange"),
        .init(name: "Other Income", type: .income, icon: "plus.circle.fill", color: "systemGray"),
        
        // Expense categories
        .init(name: "Housing", type: .expense, icon: "house.fill", color: "systemBlue"),
        .init(name: "Transportation", type: .expense, icon: "car.fill", color: "systemRed"),
        .init(name: "Food", type: .expense, icon: "fork.knife", color: "systemOrange"),
        .init(name: "Utilities", type: .expense, icon: "bolt.fill", color: "systemYellow"),
        .init(name: "Healthcare", type: .expense, icon: "cross.fill", color: "systemRed"),
        .init(name: "Entertainment", type: .expense, icon: "tv.fill", color: "systemPurple"),
        .init(name: "Shopping", type: .expense, icon: "cart.fill", color: "systemBlue"),
        .init(name: "Subscription", type: .expense, icon: "repeat", color: "systemGreen"),
        .init(name: "Credit Card", type: .expense, icon: "creditcard.fill", color: "systemGray"),
        .init(name: "Taxes", type: .expense, icon: "doc.text.fill", color: "systemRed"),
        .init(name: "Gifts", type: .expense, icon: "gift.fill", color: "systemPink"),
        .init(name: "Other Expenses", type: .expense, icon: "minus.circle.fill", color: "systemGray")
    ]
    
    struct SystemCategory {
        let name: String
        let type: TransactionType
        let icon: String
        let color: String
    }
} 