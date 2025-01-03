import SwiftUI
import SwiftData

struct ExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @State private var showingAddExpense = false
    @State private var selectedTransaction: Transaction?
    @State private var transactionToDelete: Transaction?
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(activeTransactions) { transaction in
                    Button(action: {
                        selectedTransaction = transaction
                    }) {
                        TransactionRowView(transaction: transaction, showSchedule: true)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowInsets(EdgeInsets())
                }
                .onDelete { indexSet in
                    indexSetToDelete = indexSet
                    if let index = indexSet.first {
                        let transactionsToDelete = activeTransactions
                        transactionToDelete = transactionsToDelete[index]
                        showingDeleteAlert = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddExpense = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.red)
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddTransactionView(transactionType: .expense)
                    .modelContainer(modelContext.container)
            }
            .sheet(item: $selectedTransaction) { transaction in
                EditTransactionView(transaction: transaction)
                    .modelContainer(modelContext.container)
            }
            .alert("Delete Expense", isPresented: $showingDeleteAlert) {
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
    
    var activeTransactions: [Transaction] {
        transactions.filter { transaction in
            transaction.type == .expense && 
            (transaction.schedule != nil || transaction.status == .pending)
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        let transactionsToDelete = activeTransactions
        for index in offsets {
            let transaction = transactionsToDelete[index]
            
            // Revert the balance change if needed
            if let account = transaction.account {
                account.balance += transaction.amount // Note: Adding for expense since we're removing it
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