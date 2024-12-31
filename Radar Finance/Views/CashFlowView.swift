import SwiftUI
import SwiftData
import Charts

struct CashFlowView: View {
    @Query private var transactions: [Transaction]
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var selectedMonth: Date = Date()
    @State private var selectedAccount: Account?
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault }
    }
    
    private struct MonthlyFlow: Identifiable {
        let id = UUID()
        let month: Date
        let income: Decimal
        let expenses: Decimal
        
        var isOverspent: Bool {
            expenses > income
        }
        
        var spentRatio: Double {
            guard income != 0 else { return 1.0 }
            return Double(truncating: expenses as NSDecimalNumber) / 
                   Double(truncating: income as NSDecimalNumber)
        }
        
        var overspentRatio: Double {
            if !isOverspent { return 0 }
            guard income != 0 else { return 1.0 }
            return Double(truncating: (expenses - income) as NSDecimalNumber) / 
                   Double(truncating: income as NSDecimalNumber)
        }
        
        var remainingIncome: Decimal {
            income - expenses
        }
        
        var spendingPercentage: String {
            guard income != 0 else {
                if expenses > 0 {
                    return "100% Overspent"
                }
                return "0% Spent"
            }
            
            let percentage = ((expenses / income) * 100).rounded(0)
            if percentage > 100 {
                return "\(percentage - 100)% Overspent"
            } else {
                return "\(percentage)% Spent"
            }
        }
    }
    
    private func getMonthlyFlows() -> [MonthlyFlow] {
        let calendar = Calendar.current
        
        // Update filtering to include account
        let filtered = transactions.filter { 
            $0.status == .completed &&
            ($0.account?.id == selectedAccount?.id || selectedAccount == nil)
        }
        
        // Group transactions by month
        let grouped = Dictionary(grouping: filtered) { transaction -> Date in
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            return calendar.date(from: components) ?? transaction.date
        }
        
        // Convert to MonthlyFlow objects
        return grouped.map { date, monthTransactions in
            // Calculate total income for the month
            let income = monthTransactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
            // Calculate total expenses for the month
            let expenses = monthTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }
            
            return MonthlyFlow(
                month: date,
                income: income,
                expenses: expenses
            )
        }
        .sorted { $0.month > $1.month } // Sort newest first
    }
    
    private func createChart(for flow: MonthlyFlow, height: CGFloat) -> some View {
        VStack {
            Chart {
                // Base spending in red
                SectorMark(
                    angle: PlottableValue.value("Spent", flow.spentRatio),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(.red)
                
                if flow.isOverspent {
                    // Additional overspent portion in lighter red
                    SectorMark(
                        angle: PlottableValue.value("Overspent", flow.overspentRatio),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(.red.opacity(0.5))
                } else {
                    // Remaining portion in green (only shown if not overspent)
                    SectorMark(
                        angle: PlottableValue.value("Remaining", 1.0 - flow.spentRatio),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(.green)
                }
            }
            .frame(height: height)
            
            Text(flow.spendingPercentage)
                .font(.subheadline)
                .foregroundColor(flow.isOverspent ? .red : .secondary)
                .padding(.top, 4)
        }
    }
    
    private func calculateOverspentPercentage(income: Decimal, expenses: Decimal) -> String {
        guard income != 0 else {
            if expenses > 0 {
                return "100% Overspent"
            }
            return "0% Spent"
        }
        
        let percentage = ((expenses / income) * 100).rounded(0)
        if percentage > 100 {
            return "\(percentage - 100)% Overspent"
        } else {
            return "\(percentage)% Spent"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if accounts.isEmpty {
                        Text("Please add an account to view cash flow")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 20) {
                            VStack(spacing: 20) {
                                AccountPickerView(selectedAccount: $selectedAccount)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .shadow(radius: 2)
                                    .padding(.horizontal)
                            }
                            
                            if selectedAccount != nil {
                                let flows = getMonthlyFlows()
                                
                                // Current Month Chart
                                if let currentMonth = flows.first {
                                    VStack(alignment: .leading) {
                                        Text(currentMonth.month.formatted(.dateTime.month(.wide).year()))
                                            .font(.headline)
                                        
                                        createChart(for: currentMonth, height: 200)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Circle()
                                                    .fill(.green)
                                                    .frame(width: 10, height: 10)
                                                Text("Income: \(currentMonth.income.formatted(.currency(code: "USD")))")
                                            }
                                            
                                            HStack {
                                                Circle()
                                                    .fill(.red)
                                                    .frame(width: 10, height: 10)
                                                Text("Expenses: \(currentMonth.expenses.formatted(.currency(code: "USD")))")
                                            }
                                            
                                            Text("Remaining: \(currentMonth.remainingIncome.formatted(.currency(code: "USD")))")
                                                .foregroundColor(currentMonth.remainingIncome >= 0 ? .green : .red)
                                                .font(.headline)
                                        }
                                        .padding(.top)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .shadow(radius: 2)
                                    .padding(.horizontal)
                                }
                                
                                // Previous Months
                                ForEach(flows.dropFirst()) { flow in
                                    VStack(alignment: .leading) {
                                        Text(flow.month.formatted(.dateTime.month(.wide).year()))
                                            .font(.headline)
                                        
                                        createChart(for: flow, height: 150)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Circle()
                                                    .fill(.green)
                                                    .frame(width: 10, height: 10)
                                                Text("Income: \(flow.income.formatted(.currency(code: "USD")))")
                                            }
                                            
                                            HStack {
                                                Circle()
                                                    .fill(.red)
                                                    .frame(width: 10, height: 10)
                                                Text("Expenses: \(flow.expenses.formatted(.currency(code: "USD")))")
                                            }
                                            
                                            Text("Remaining: \(flow.remainingIncome.formatted(.currency(code: "USD")))")
                                                .foregroundColor(flow.remainingIncome >= 0 ? .green : .red)
                                                .font(.headline)
                                        }
                                        .padding(.top)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .shadow(radius: 2)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cash Flow")
        }
        .scrollContentBackground(.hidden)
        .animatedBackground()
        .onAppear {
            if selectedAccount == nil && !accounts.isEmpty {
                selectedAccount = defaultAccount ?? accounts[0]
            }
        }
    }
}

// Add this extension to rotate the chart
extension View {
    func rotateChart() -> some View {
        self.rotationEffect(.degrees(-90))  // Rotate to start from top
    }
} 