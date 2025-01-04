import SwiftUI
import SwiftData
import Foundation

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Bindable var transaction: Transaction
    @State private var amountString: String
    @State private var pendingAmount: Decimal?
    @State private var showingAddCategory = false
    @State private var isRecurring: Bool
    @State private var frequency: Frequency
    @State private var startDate: Date
    @State private var firstMonthlyDate: Int
    @State private var secondMonthlyDate: Int
    @State private var showingNoAccountAlert = false
    @State private var navigateToAccounts = false
    
    init(transaction: Transaction) {
        self.transaction = transaction
        self._amountString = State(initialValue: String(describing: transaction.amount))
        self._isRecurring = State(initialValue: transaction.schedule != nil)
        self._frequency = State(initialValue: transaction.schedule?.frequency ?? .monthly)
        self._startDate = State(initialValue: transaction.schedule?.startDate ?? Date())
        self._firstMonthlyDate = State(initialValue: transaction.schedule?.firstMonthlyDate ?? 1)
        self._secondMonthlyDate = State(initialValue: transaction.schedule?.secondMonthlyDate ?? 15)
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
                    
                    Picker("Category", selection: $transaction.category) {
                        Text("None").tag(nil as Category?)
                        ForEach(Category.categories(for: transaction.type)) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundColor(Color(hex: category.color))
                                .tag(category as Category?)
                        }
                    }
                    
                    Picker("Account", selection: $transaction.account) {
                        Text("None").tag(nil as Account?)
                        ForEach(accounts) { account in
                            Text(account.name).tag(account as Account?)
                        }
                    }
                }
                
                Section("Schedule") {
                    Toggle("Recurring Transaction", isOn: $isRecurring)
                    
                    if isRecurring {
                        Picker("Frequency", selection: $frequency) {
                            ForEach([Frequency.weekly, .biweekly, .monthly, .twiceMonthly, .annual]) { freq in
                                Text(freq.description).tag(freq)
                            }
                        }
                        
                        if frequency == .twiceMonthly {
                            Picker("First Monthly Date", selection: $firstMonthlyDate) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)").tag(day)
                                }
                            }
                            
                            Picker("Second Monthly Date", selection: $secondMonthlyDate) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)").tag(day)
                                }
                            }
                        } else {
                            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        }
                    }
                }
                
                Section("Notes") {
                    CustomTextEditor(text: $transaction.notes.bound)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Edit \(transaction.type == .income ? "Income" : "Expense")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                    }
                }
            }
        }
        .environment(\.sizeCategory, .medium)
        .dynamicTypeSize(.medium)
        .environment(\.legibilityWeight, .regular)
        .fontWeight(.regular)
    }
    
    private func saveTransaction() {
        if let amount = pendingAmount {
            transaction.amount = amount
        }
        
        if isRecurring {
            if transaction.schedule == nil {
                transaction.schedule = Schedule(
                    frequency: frequency,
                    startDate: startDate,
                    firstMonthlyDate: frequency == .twiceMonthly ? firstMonthlyDate : nil,
                    secondMonthlyDate: frequency == .twiceMonthly ? secondMonthlyDate : nil
                )
            } else {
                transaction.schedule?.frequency = frequency
                transaction.schedule?.startDate = startDate
                transaction.schedule?.firstMonthlyDate = frequency == .twiceMonthly ? firstMonthlyDate : nil
                transaction.schedule?.secondMonthlyDate = frequency == .twiceMonthly ? secondMonthlyDate : nil
            }
        } else {
            if let schedule = transaction.schedule {
                transaction.schedule = nil
                transaction.modelContext?.delete(schedule)
            }
        }
        
        try? transaction.modelContext?.save()
        dismiss()
    }
}

// Helper extension for optional string binding
extension Optional where Wrapped == String {
    var bound: String {
        get { self ?? "" }
        set { self = newValue.isEmpty ? nil : newValue }
    }
} 