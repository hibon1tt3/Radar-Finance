import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @State private var selectedAccount: Account?
    @State private var selectedTransaction: Transaction?
    @State private var showingQuickTransactionSheet = false
    @State private var quickTransactionSheet: QuickTransactionSheet?
    @State private var transactionToDelete: Transaction?
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    
    var completedTransactions: [Transaction] {
        transactions.filter { transaction in
            if let selectedAccount = selectedAccount {
                return transaction.status == .completed && transaction.account?.id == selectedAccount.id
            } else {
                return transaction.status == .completed
            }
        }
    }
    
    var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: completedTransactions) { transaction in
            let date = transaction.date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
        return grouped.sorted { $0.0 > $1.0 }
    }
    
    private func calculateRunningBalance(for transactions: [Transaction]) -> [Transaction: Decimal] {
        var balanceMap: [Transaction: Decimal] = [:]
        var runningBalance: [String: Decimal] = [:] // Track balance per account
        
        // Sort transactions by date, oldest first
        let sortedTransactions = transactions.sorted { $0.date < $1.date }
        
        for transaction in sortedTransactions {
            if let account = transaction.account {
                let amount = transaction.type == .expense ? -transaction.amount : transaction.amount
                runningBalance[account.name] = (runningBalance[account.name] ?? account.startingBalance) + amount
                balanceMap[transaction] = runningBalance[account.name]
            }
        }
        
        return balanceMap
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Account Picker
                if !accounts.isEmpty {
                    AccountPickerView(selectedAccount: $selectedAccount)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                }
                
                // Transactions List
                List {
                    ForEach(groupedTransactions, id: \.0) { month, transactions in
                        Section(header: Text(month)) {
                            let balanceMap = calculateRunningBalance(for: transactions)
                            ForEach(transactions) { transaction in
                                TransactionRowView(
                                    transaction: transaction,
                                    balance: balanceMap[transaction],
                                    showCompletionDate: true
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTransaction = transaction
                                }
                            }
                            .onDelete { indexSet in
                                indexSetToDelete = indexSet
                                if let index = indexSet.first {
                                    transactionToDelete = transactions[index]
                                    showingDeleteAlert = true
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
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
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
                    .modelContainer(modelContext.container)
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
                    .modelContainer(modelContext.container)
            }
            .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    indexSetToDelete = nil
                    transactionToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let indexSet = indexSetToDelete {
                        deleteTransactions(at: indexSet)
                    }
                }
            } message: {
                if let transaction = transactionToDelete {
                    Text("Are you sure you want to delete '\(transaction.title)'? This action cannot be undone.")
                }
            }
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        guard let monthTransactions = groupedTransactions.first(where: { _, transactions in
            transactions.contains(where: { $0.id == transactionToDelete?.id })
        })?.1 else { return }
        
        for index in offsets {
            let transaction = monthTransactions[index]
            
            // Revert the balance change
            if let account = transaction.account {
                if transaction.type == .income {
                    account.balance -= transaction.amount
                } else {
                    account.balance += transaction.amount
                }
            }
            
            modelContext.delete(transaction)
        }
        
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        
        // Clear the state
        indexSetToDelete = nil
        transactionToDelete = nil
    }
}

private struct QuickTransactionSheet: Identifiable {
    let id = UUID()
    let type: TransactionType
} 