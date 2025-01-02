import Foundation

enum Category: String, CaseIterable, Identifiable {
    // Income Categories
    case salary = "Salary"
    case investments = "Investments"
    case freelance = "Freelance"
    case gifts = "Gifts"
    case reimbursement = "Reimbursement"
    case otherIncome = "Other Income"
    
    // Expense Categories
    case housing = "Housing"
    case utilities = "Utilities"
    case food = "Food & Dining"
    case transportation = "Transportation"
    case healthcare = "Healthcare"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case education = "Education"
    case insurance = "Insurance"
    case savings = "Savings"
    case otherExpense = "Other Expense"
    
    var id: String { rawValue }
    
    var type: TransactionType {
        switch self {
        case .salary, .investments, .freelance, .gifts, .reimbursement, .otherIncome:
            return .income
        default:
            return .expense
        }
    }
    
    var icon: String {
        switch self {
        case .salary: return "dollarsign.circle"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .freelance: return "briefcase"
        case .gifts: return "gift"
        case .reimbursement: return "arrow.counterclockwise"
        case .otherIncome: return "plus.circle"
        case .housing: return "house"
        case .utilities: return "bolt"
        case .food: return "fork.knife"
        case .transportation: return "car"
        case .healthcare: return "cross"
        case .entertainment: return "tv"
        case .shopping: return "cart"
        case .education: return "book"
        case .insurance: return "shield"
        case .savings: return "banknote"
        case .otherExpense: return "circle"
        }
    }
    
    var color: String {
        switch self {
        // Income Categories - Shades of Green and Blue
        case .salary: return "#34C759"        // Green
        case .investments: return "#007AFF"    // Blue
        case .freelance: return "#5856D6"      // Purple
        case .gifts: return "#32ADE6"         // Light Blue
        case .reimbursement: return "#00B386"  // Teal
        case .otherIncome: return "#4CD964"    // Light Green
        
        // Expense Categories - Varied colors for different expense types
        case .housing: return "#FF3B30"        // Red
        case .utilities: return "#FF9500"      // Orange
        case .food: return "#B4D147"          // Lime Green
        case .transportation: return "#5856D6"  // Purple
        case .healthcare: return "#FF2D55"     // Pink
        case .entertainment: return "#AF52DE"   // Purple
        case .shopping: return "#FF6B6B"       // Coral
        case .education: return "#5AC8FA"      // Light Blue
        case .insurance: return "#FF8000"      // Dark Orange
        case .savings: return "#30B0C7"        // Turquoise
        case .otherExpense: return "#8E8E93"   // Gray
        }
    }
    
    static func categories(for type: TransactionType) -> [Category] {
        Category.allCases.filter { $0.type == type }
    }
} 