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
        guard showSchedule else { return nil }
        
        // If it's not a recurring transaction but has a status of pending, show the due date
        if transaction.schedule == nil && transaction.status == .pending {
            return "Due \(transaction.date.formatted(date: .abbreviated, time: .omitted))"
        }
        
        // Handle recurring schedules
        guard let schedule = transaction.schedule else { return nil }
        
        let calendar = Calendar.current
        
        switch schedule.frequency {
        case .twiceMonthly:
            return "Monthly on \(schedule.firstMonthlyDate?.ordinal ?? "1st") and \(schedule.secondMonthlyDate?.ordinal ?? "15th")"
            
        case .monthly:
            let day = calendar.component(.day, from: schedule.startDate)
            return "Monthly on the \(day.ordinal)"
            
        case .weekly:
            let weekday = calendar.component(.weekday, from: schedule.startDate)
            let weekdayName = calendar.weekdaySymbols[weekday - 1]
            return "Weekly on \(weekdayName)"
            
        case .biweekly:
            let weekday = calendar.component(.weekday, from: schedule.startDate)
            let weekdayName = calendar.weekdaySymbols[weekday - 1]
            return "Biweekly on \(weekdayName)"
            
        case .annual:
            let month = calendar.component(.month, from: schedule.startDate)
            let day = calendar.component(.day, from: schedule.startDate)
            let monthName = calendar.monthSymbols[month - 1]
            return "Yearly on \(monthName) \(day.ordinal)"

        default:
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
                
                if let dateText = dateText {
                    Text(dateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                
                if showSchedule, let scheduleText = scheduleText {
                    Text(scheduleText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let balance = balance {
                    Text("Balance: \(balance.formatted(.currency(code: "USD")))")
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