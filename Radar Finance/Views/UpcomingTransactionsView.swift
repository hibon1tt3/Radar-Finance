import SwiftUI

struct UpcomingTransactionsView: View {
    let transactions: [Transaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Transactions")
                .font(.headline)
            
            if transactions.isEmpty {
                Text("No upcoming transactions")
                    .foregroundColor(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(transactions) { transaction in
                    UpcomingTransactionRow(transaction: transaction)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}

struct UpcomingTransactionRow: View {
    @Environment(\.modelContext) private var modelContext
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.title)
                    .font(.subheadline)
                
                if let date = transaction.schedule?.startDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(transaction.amount.formatted(.currency(code: "USD")))
                    .foregroundColor(transaction.type == .income ? .green : .primary)
                
                Button("Mark \(transaction.type == .income ? "Received" : "Paid")") {
                    markTransactionComplete()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func markTransactionComplete() {
        transaction.status = .completed
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
    }
} 