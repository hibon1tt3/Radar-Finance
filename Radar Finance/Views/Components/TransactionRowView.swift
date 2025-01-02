import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    var showOccurrenceDate = false
    var occurrenceDate: Date?
    var balance: Decimal?
    
    private var displayAmount: Decimal {
        // Make expense amounts negative
        transaction.type == .expense ? -transaction.amount : transaction.amount
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.headline)
                
                if let category = transaction.category {
                    Label {
                        Text(category.rawValue)
                            .font(.caption)
                            .foregroundColor(Color(hex: category.color))
                    } icon: {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.color))
                    }
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
                } else if let account = transaction.account {
                    Text(account.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(displayAmount.formatted(.currency(code: "USD")))
                    .font(.headline)
                    .foregroundColor(transaction.type == .income ? .green : .red)
                
                if let balance = balance {
                    Text(balance.formatted(.currency(code: "USD")))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// Add extension for ordinal numbers
extension Int {
    var ordinal: String {
        let suffix: String
        switch self {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(self)\(suffix)"
    }
} 