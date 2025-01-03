import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    var showOccurrenceDate = false
    var occurrenceDate: Date?
    var balance: Decimal?
    var showSchedule = false
    var showCompletionDate = false
    
    private var displayAmount: Decimal {
        // Make expense amounts negative
        transaction.type == .expense ? -transaction.amount : transaction.amount
    }
    
    private var scheduleText: String? {
        guard showSchedule, let schedule = transaction.schedule else { return nil }
        if schedule.frequency == .twiceMonthly {
            return "Monthly on \(schedule.firstMonthlyDate ?? 1) and \(schedule.secondMonthlyDate ?? 15)"
        } else {
            return "\(schedule.frequency.description) from \(schedule.startDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }
    
    private var dateText: String? {
        guard showCompletionDate else { return nil }
        return "\(transaction.type == .expense ? "Paid" : "Received") \(transaction.date.formatted(date: .abbreviated, time: .omitted))"
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
                
                if let scheduleText = scheduleText {
                    Text(scheduleText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let dateText = dateText {
                    Text(dateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let balance = balance {
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