import SwiftUI
import SwiftData

struct ExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @State private var showingAddExpense = false
    @State private var selectedTransaction: Transaction?
    
    var activeTransactions: [Transaction] {
        transactions.filter { transaction in
            transaction.type == .expense && 
            (transaction.schedule != nil || transaction.status == .pending)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(activeTransactions) { transaction in
                    Button(action: {
                        selectedTransaction = transaction
                    }) {
                        TransactionRowView(transaction: transaction)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowInsets(EdgeInsets())
                }
                .onDelete { indexSet in
                    deleteTransactions(at: indexSet)
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
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        let transactionsToDelete = activeTransactions
        for index in offsets {
            let transaction = transactionsToDelete[index]
            deleteTransaction(transaction)
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        if let schedule = transaction.schedule {
            transaction.schedule = nil
            modelContext.delete(schedule)
        }
        
        modelContext.delete(transaction)
        
        try? modelContext.save()
    }
} 