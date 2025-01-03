import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var selectedTransaction: Transaction?
    @State private var showingQuickTransactionSheet = false
    @State private var quickTransactionSheet: QuickTransactionSheet?
    @State private var transactionToDelete: Transaction?
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    
    var completedTransactions: [Transaction] {
        transactions.filter { $0.status == .completed }
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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedTransactions, id: \.0) { month, transactions in
                    Section(header: Text(month)) {
                        ForEach(transactions) { transaction in
                            Button(action: {
                                selectedTransaction = transaction
                            }) {
                                TransactionRowView(transaction: transaction, showCompletionDate: true)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowInsets(EdgeInsets())
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