import SwiftUI
import SwiftData
import Foundation

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var transaction: Transaction
    @State private var amountString: String
    @State private var pendingAmount: Decimal?
    
    init(transaction: Transaction) {
        self.transaction = transaction
        self._amountString = State(initialValue: String(describing: transaction.amount))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction Details") {
                    CustomTextField(text: $transaction.title, placeholder: "Title")
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("$")
                        CustomTextField(
                            text: $amountString,
                            placeholder: "Amount",
                            keyboardType: .decimalPad
                        )
                    }
                    .onChange(of: amountString) { _, newValue in
                        if let amount = Decimal(string: newValue) {
                            pendingAmount = amount
                        }
                    }
                    
                    Toggle("Estimated Amount", isOn: $transaction.isEstimated)
                    
                    if let category = transaction.category {
                        HStack {
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundColor(Color(hex: category.color))
                            Spacer()
                            Text("Category")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let account = transaction.account {
                        HStack {
                            Text(account.name)
                            Spacer()
                            Text("Account")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let schedule = transaction.schedule {
                    Section("Schedule") {
                        Text(schedule.frequency.description)
                        if schedule.frequency == .twiceMonthly {
                            Text("Monthly on days \(schedule.firstMonthlyDate ?? 1) and \(schedule.secondMonthlyDate ?? 15)")
                        } else {
                            DatePicker(
                                "Start Date",
                                selection: Binding(
                                    get: { schedule.startDate },
                                    set: { schedule.startDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                        }
                    }
                }
                
                Section("Notes") {
                    CustomTextEditor(text: $transaction.notes.bound)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Edit \(transaction.type == .income ? "Income" : "Expense")")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = pendingAmount {
                            transaction.amount = amount
                        }
                        try? transaction.modelContext?.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper extension for optional string binding
extension Optional where Wrapped == String {
    var bound: String {
        get { self ?? "" }
        set { self = newValue.isEmpty ? nil : newValue }
    }
} 