import SwiftUI
import SwiftData
import Charts

struct ProjectionsView: View {
    @Query private var transactions: [Transaction]
    @Query private var schedules: [Schedule]
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var selectedAccount: Account?
    @State private var selectedPoint: MonthlyProjection?
    
    private struct MonthlyProjection: Identifiable, Equatable {
        let id = UUID()
        let month: Date
        let scheduledIncome: Decimal
        let scheduledExpenses: Decimal
        let projectedBalance: Decimal
        
        var remainingBalance: Decimal {
            scheduledIncome - scheduledExpenses
        }
        
        var formattedMonth: String {
            month.formatted(.dateTime.month(.wide).year())
        }
        
        var shortMonth: String {
            month.formatted(.dateTime.month(.abbreviated))
        }
        
        static func == (lhs: MonthlyProjection, rhs: MonthlyProjection) -> Bool {
            lhs.month == rhs.month &&
            lhs.scheduledIncome == rhs.scheduledIncome &&
            lhs.scheduledExpenses == rhs.scheduledExpenses &&
            lhs.projectedBalance == rhs.projectedBalance
        }
    }
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault }
    }
    
    private func getProjections() -> [MonthlyProjection] {
        let calendar = Calendar.current
        let currentDate = Date()
        var projections: [MonthlyProjection] = []
        let startingBalance = selectedAccount?.balance ?? Decimal.zero
        
        // Get next 12 months, excluding current month
        let startDate = calendar.date(
            byAdding: .month,
            value: 1,
            to: calendar.startOfMonth(for: currentDate)
        ) ?? currentDate
        
        // Generate dates for next 12 months
        let dates = (0..<12).compactMap { month in
            calendar.date(byAdding: .month, value: month, to: startDate)
        }
        
        // Get pending transactions with schedules
        let scheduledTransactions = transactions.filter { 
            $0.status == .pending && $0.schedule != nil &&
            ($0.account?.id == selectedAccount?.id || selectedAccount == nil)
        }
        
        // Calculate projections for each month
        var runningBalance = startingBalance
        
        for date in dates {
            // Calculate scheduled income for the month
            let income = scheduledTransactions
                .filter { $0.type == .income }
                .reduce(into: Decimal.zero) { total, transaction in
                    if let schedule = transaction.schedule {
                        total += transaction.amount * schedule.calculateMonthlyOccurrences(for: date)
                    }
                }
            
            // Calculate scheduled expenses for the month
            let expenses = scheduledTransactions
                .filter { $0.type == .expense }
                .reduce(into: Decimal.zero) { total, transaction in
                    if let schedule = transaction.schedule {
                        total += transaction.amount * schedule.calculateMonthlyOccurrences(for: date)
                    }
                }
            
            // For each month, we:
            // 1. Start with previous month's ending balance (runningBalance)
            // 2. Add this month's income
            // 3. Subtract this month's expenses
            let monthlyBalance = runningBalance + income - expenses
            
            projections.append(MonthlyProjection(
                month: date,
                scheduledIncome: income,
                scheduledExpenses: expenses,
                projectedBalance: monthlyBalance
            ))
            
            // Update running balance for next month
            runningBalance = monthlyBalance
        }
        
        return projections
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if accounts.isEmpty {
                        Text("Please add an account to view projections")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 20) {
                            // Account Picker
                            VStack(spacing: 20) {
                                AccountPickerView(selectedAccount: $selectedAccount)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .shadow(radius: 2)
                                    .padding(.horizontal)
                            }
                            
                            if selectedAccount != nil {
                                let projections = getProjections()
                                
                                // Monthly Projections List
                                ForEach(projections) { projection in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(projection.formattedMonth)
                                                .font(.headline)
                                            Spacer()
                                            Text("Balance: \(projection.projectedBalance.formatted(.currency(code: "USD")))")
                                                .foregroundColor(projection.projectedBalance >= 0 ? .green : .red)
                                                .font(.subheadline.bold())
                                        }
                                        
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(.green)
                                                        .frame(width: 8, height: 8)
                                                    Text("Income: \(projection.scheduledIncome.formatted(.currency(code: "USD")))")
                                                        .font(.subheadline)
                                                }
                                                
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(.red)
                                                        .frame(width: 8, height: 8)
                                                    Text("Expenses: \(projection.scheduledExpenses.formatted(.currency(code: "USD")))")
                                                        .font(.subheadline)
                                                }
                                            }
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .shadow(radius: 2)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Projections")
            .onAppear {
                if selectedAccount == nil && !accounts.isEmpty {
                    selectedAccount = defaultAccount ?? accounts[0]
                }
            }
        }
    }
}

// Helper extension for date calculations
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        guard let start = self.date(from: dateComponents([.year, .month], from: date)),
              let end = self.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return date }
        return end
    }
}

// Helper extension for Schedule
extension Schedule {
    func calculateMonthlyOccurrences(for date: Date) -> Decimal {
        switch frequency {
        case .weekly:
            return 4  // Approximately 4 weeks per month
        case .biweekly:
            return 2  // Twice per month
        case .monthly:
            return 1  // Once per month
        case .twiceMonthly:
            return 2  // Twice per month
        case .annual:
            // Check if this is the month when the annual payment occurs
            let calendar = Calendar.current
            let scheduleMonth = calendar.component(.month, from: startDate)
            let targetMonth = calendar.component(.month, from: date)
            return scheduleMonth == targetMonth ? 1 : 0
        default:
            return 1
        }
    }
} 