import SwiftUI
import SwiftData

struct IncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @State private var showingAddIncome = false
    @State private var selectedTransaction: Transaction?
    
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
            .navigationTitle("Income")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddIncome = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingAddIncome) {
                AddTransactionView(transactionType: .income)
                    .modelContainer(modelContext.container)
            }
            .sheet(item: $selectedTransaction) { transaction in
                EditTransactionView(transaction: transaction)
                    .modelContainer(modelContext.container)
            }
        }
    }
    
    var activeTransactions: [Transaction] {
        transactions.filter { transaction in
            transaction.type == .income && 
            (transaction.schedule != nil || transaction.status == .pending)
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        let transactionsToDelete = activeTransactions
        for index in offsets {
            let transaction = transactionsToDelete[index]
            modelContext.delete(transaction)
        }
        try? modelContext.save()
    }
} 