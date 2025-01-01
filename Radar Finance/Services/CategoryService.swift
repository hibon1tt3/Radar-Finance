import SwiftData
import SwiftUI

struct CategoryService {
    static func createDefaultCategories(in context: ModelContext) {
        // Check if we have any categories
        let descriptor = FetchDescriptor<Category>()
        guard let count = try? context.fetch(descriptor).count, count == 0 else {
            return // Categories already exist
        }
        
        // Default Income Categories
        let incomeCategories = [
            ("Salary", "dollarsign.circle", "#34C759"),
            ("Investments", "chart.line.uptrend.xyaxis", "#007AFF"),
            ("Freelance", "briefcase", "#5856D6"),
            ("Gifts", "gift", "#FF2D55"),
            ("Reimbursement", "arrow.counterclockwise", "#FF9500"),
            ("Other Income", "plus.circle", "#000000")
        ]
        
        // Default Expense Categories
        let expenseCategories = [
            ("Housing", "house", "#FF9500"),
            ("Transportation", "car", "#5856D6"),
            ("Food", "fork.knife", "#34C759"),
            ("Utilities", "bolt", "#007AFF"),
            ("Healthcare", "cross", "#FF2D55"),
            ("Entertainment", "tv", "#AF52DE"),
            ("Shopping", "cart", "#FF3B30"),
            ("Credit Card", "creditcard", "#FF2D55"),
            ("Subscription", "repeat", "#5856D6"),
            ("Taxes", "percent", "#000000"),
            ("Other Expenses", "minus.circle", "#000000")
        ]
        
        // Create Income Categories
        for (name, icon, color) in incomeCategories {
            let category = Category(
                name: name,
                type: .income,
                icon: icon,
                color: color
            )
            context.insert(category)
        }
        
        // Create Expense Categories
        for (name, icon, color) in expenseCategories {
            let category = Category(
                name: name,
                type: .expense,
                icon: icon,
                color: color
            )
            context.insert(category)
        }
        
        // Save the changes
        try? context.save()
    }
} 