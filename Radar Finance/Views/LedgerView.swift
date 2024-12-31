import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @State private var selectedTransaction: Transaction?
    @State private var transactionToDelete: Transaction?
    @State private var showingQuickTransactionSheet = false
    @State private var quickTransactionSheet: QuickTransactionSheet?
    @State private var selectedAccount: Account?
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault }
    }
    
    private var filteredTransactions: [Transaction] {
        let accountToFilter = selectedAccount ?? defaultAccount
        return transactions.filter { transaction in
            if let accountToFilter = accountToFilter {
                return transaction.account?.id == accountToFilter.id
            }
            return true // Show all if no account selected
        }
    }
    
    // Group transactions by month
    private var groupedTransactions: [(String, [Transaction])] {
        let sortedTransactions = filteredTransactions
            .filter { $0.status == .completed }
            .sorted { $0.date > $1.date }  // Sort by date descending for display
        
        let grouped = Dictionary(grouping: sortedTransactions) { transaction in
            let date = transaction.date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
        
        // Sort months in descending order
        return grouped.sorted { month1, month2 in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let date1 = formatter.date(from: month1.key) ?? Date.distantPast
            let date2 = formatter.date(from: month2.key) ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func getTransactionsForAccount(_ account: Account?) -> [Transaction] {
        guard let account = account else { return [] }
        return transactions
            .filter { $0.account?.id == account.id }
            .sorted { $0.date > $1.date }  // Sort by date descending
    }
    
    private func calculateRunningBalances() -> [UUID: Decimal] {
        var balances: [UUID: Decimal] = [:]
        var runningBalance = selectedAccount?.startingBalance ?? Decimal.zero
        
        // Get all transactions for this account and sort by date (oldest first)
        let allTransactions = filteredTransactions
            .filter { $0.status == .completed }
            .sorted { $0.date < $1.date }
        
        // Calculate running balance for each transaction
        for transaction in allTransactions {
            if transaction.type == .income {
                runningBalance += transaction.amount
            } else {
                runningBalance -= transaction.amount
            }
            balances[transaction.id] = runningBalance
        }
        
        return balances
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Account Picker
                    AccountPickerView(selectedAccount: $selectedAccount)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    
                    // Calculate balances once for all transactions
                    let balances = calculateRunningBalances()
                    
                    // Transactions List
                    ForEach(groupedTransactions, id: \.0) { month, monthTransactions in
                        VStack(alignment: .leading, spacing: 8) {
                            // Month header outside the tile
                            Text(month)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Transactions tile
                            VStack(alignment: .leading) {
                                ForEach(monthTransactions.sorted { $0.date > $1.date }) { transaction in
                                    Button(action: {
                                        selectedTransaction = transaction
                                    }) {
                                        TransactionRowView(
                                            transaction: transaction,
                                            balance: balances[transaction.id]
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if transaction.id != monthTransactions.last?.id {
                                        Divider()
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.vertical)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Ledger")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingQuickTransactionSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .animatedBackground()
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
        .confirmationDialog("Add Quick Transaction", 
                          isPresented: $showingQuickTransactionSheet,
                          titleVisibility: .visible) {
            Button("Add Quick Income") {
                quickTransactionSheet = QuickTransactionSheet(type: .income)
            }
            Button("Add Quick Expense") {
                quickTransactionSheet = QuickTransactionSheet(type: .expense)
            }
            Button("Cancel", role: .cancel) {
                quickTransactionSheet = nil
            }
        }
        .sheet(item: $quickTransactionSheet) { sheet in
            QuickTransactionView(transactionType: sheet.type)
        }
        .onAppear {
            // Set default account when view appears if no account is selected
            if selectedAccount == nil {
                selectedAccount = defaultAccount
            }
        }
    }
}

private struct QuickTransactionSheet: Identifiable {
    let id = UUID()
    let type: TransactionType
} 