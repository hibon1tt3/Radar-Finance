import SwiftUI
import SwiftData
import Charts

struct SpendingView: View {
    @Query private var transactions: [Transaction]
    @Query(sort: \Account.name) private var accounts: [Account]
    @State private var selectedAccount: Account?
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault }
    }
    
    private struct CategorySpending: Identifiable {
        let id = UUID()
        let month: Date
        let categoryName: String
        let categoryColor: String
        let amount: Decimal
        let percentage: Double
        
        var color: Color {
            Color(hex: categoryColor)
        }
    }
    
    private struct MonthlySpending: Identifiable {
        let id = UUID()
        let month: Date
        let categories: [CategorySpending]
        let totalSpent: Decimal
        
        var formattedMonth: String {
            month.formatted(.dateTime.month(.wide).year())
        }
    }
    
    private func getMonthlySpending() -> [MonthlySpending] {
        let calendar = Calendar.current
        
        // Update filtering to include account
        let filtered = transactions.filter { 
            $0.status == .completed &&
            ($0.account?.id == selectedAccount?.id || selectedAccount == nil)
        }
        
        // Group transactions by month, only completed transactions
        let grouped = Dictionary(grouping: filtered.filter { 
            $0.type == .expense  // Only completed expenses
        }) { transaction -> Date in
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            return calendar.date(from: components) ?? transaction.date
        }
        
        // Convert to MonthlySpending objects
        return grouped.map { date, monthTransactions in
            // Calculate total spent for the month
            let totalSpent = monthTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            
            // Group by category and calculate percentages
            let expensesByCategory = Dictionary(grouping: monthTransactions) { 
                $0.category?.rawValue ?? "Uncategorized"
            }
            
            // Calculate spending for each category
            let categorySpending = expensesByCategory.map { categoryName, transactions -> CategorySpending in
                let amount = transactions.reduce(Decimal.zero) { $0 + $1.amount }
                let percentage = Double(truncating: amount as NSDecimalNumber) / 
                               Double(truncating: totalSpent as NSDecimalNumber)
                
                return CategorySpending(
                    month: date,
                    categoryName: categoryName,
                    categoryColor: transactions.first?.category?.color ?? "#000000",
                    amount: amount,
                    percentage: percentage
                )
            }.sorted { $0.amount > $1.amount }  // Sort by amount (highest first)
            
            return MonthlySpending(
                month: date,
                categories: categorySpending,
                totalSpent: totalSpent
            )
        }
        .sorted { $0.month > $1.month }  // Sort months newest first
    }
    
    private func createChart(for spending: MonthlySpending, height: CGFloat) -> some View {
        VStack {
            Chart {
                ForEach(spending.categories) { category in
                    SectorMark(
                        angle: .value(category.categoryName, category.percentage),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(category.color)
                }
            }
            .frame(height: height)
            
            Text("Total Spent: \(spending.totalSpent.formatted(.currency(code: "USD")))")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if accounts.isEmpty {
                        Text("Please add an account to view spending")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 20) {
                            AccountPickerView(selectedAccount: $selectedAccount)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                                .padding(.horizontal)
                            
                            if selectedAccount != nil {
                                let spending = getMonthlySpending()
                                // Current Month
                                if let currentMonth = spending.first {
                                    VStack(alignment: .leading) {
                                        Text(currentMonth.formattedMonth)
                                            .font(.headline)
                                        
                                        createChart(for: currentMonth, height: 200)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(currentMonth.categories) { category in
                                                HStack {
                                                    Circle()
                                                        .fill(category.color)
                                                        .frame(width: 10, height: 10)
                                                    Text("\(category.categoryName): \(category.amount.formatted(.currency(code: "USD")))")
                                                    Spacer()
                                                    Text(String(format: "%.0f%%", category.percentage * 100))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
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
                                ForEach(spending.dropFirst()) { spending in
                                    VStack(alignment: .leading) {
                                        Text(spending.formattedMonth)
                                            .font(.headline)
                                        
                                        createChart(for: spending, height: 150)
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(spending.categories) { category in
                                                HStack {
                                                    Circle()
                                                        .fill(category.color)
                                                        .frame(width: 10, height: 10)
                                                    Text("\(category.categoryName): \(category.amount.formatted(.currency(code: "USD")))")
                                                    Spacer()
                                                    Text(String(format: "%.0f%%", category.percentage * 100))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Spending")
            .onAppear {
                if selectedAccount == nil && !accounts.isEmpty {
                    selectedAccount = defaultAccount ?? accounts[0]
                }
            }
        }
    }
} 