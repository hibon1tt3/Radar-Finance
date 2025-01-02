import SwiftUI
import SwiftData

struct CompleteTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var transaction: Transaction
    let occurrenceDate: Date
    
    @State private var completionDate: Date = Date()
    @State private var actualAmountString: String = ""
    @State private var notes: String
    
    init(transaction: Transaction, occurrenceDate: Date) {
        self.transaction = transaction
        self.occurrenceDate = occurrenceDate
        self._actualAmountString = State(initialValue: "")
        self._notes = State(initialValue: transaction.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        Text(transaction.title)
                            .font(.headline)
                        
                        if let category = transaction.category {
                            Label(category.rawValue, systemImage: category.icon)
                                .foregroundColor(Color(hex: category.color))
                        }
                    }
                    
                    Section {
                        if transaction.isEstimated {
                            LabeledContent("Estimated Amount") {
                                Text(transaction.amount.formatted(.currency(code: "USD")))
                                    .foregroundStyle(.secondary)
                            }
                            
                            CustomTextField(
                                text: $actualAmountString,
                                placeholder: "$ Actual Amount",
                                keyboardType: .decimalPad
                            )
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LabeledContent("Amount") {
                                Text(transaction.amount.formatted(.currency(code: "USD")))
                            }
                        }
                        
                        LabeledContent("Due Date") {
                            Text(occurrenceDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                        
                        DatePicker(
                            transaction.type == .expense ? "Date Paid" : "Date Received",
                            selection: $completionDate,
                            displayedComponents: .date
                        )
                    }
                    
                    if let account = transaction.account {
                        Section {
                            LabeledContent("Account") {
                                Text(account.name)
                            }
                        }
                    }
                    
                    Section("Notes") {
                        CustomTextEditor(text: $notes)
                            .frame(height: 100)
                    }
                }
                
                // Bottom button
                Button(action: completeTransaction) {
                    Text(transaction.type == .expense ? "Mark as Paid" : "Mark as Received")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(transaction.type == .expense ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(transaction.isEstimated && actualAmountString.isEmpty)
                .padding()
            }
            .navigationTitle(transaction.type == .expense ? "Mark as Paid" : "Mark as Received")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func completeTransaction() {
        // Get the final amount to use
        let finalAmount = transaction.isEstimated ? 
            (Decimal(string: actualAmountString) ?? transaction.amount) : 
            transaction.amount
        
        if transaction.schedule != nil {
            // Create a new completed transaction
            let completedTransaction = Transaction(
                title: transaction.title,
                amount: finalAmount,
                isEstimated: false,
                category: transaction.category,
                account: transaction.account,
                type: transaction.type,
                schedule: nil,
                status: .completed,
                date: completionDate,
                notes: notes
            )
            
            modelContext.insert(completedTransaction)
            
            // Update account balance
            if let account = transaction.account {
                if transaction.type == .income {
                    account.balance += finalAmount
                } else {
                    account.balance -= finalAmount
                }
            }
            
            // Add to completed occurrences
            var completedDates = transaction.completedOccurrences
            completedDates.insert(occurrenceDate)
            transaction.completedOccurrences = completedDates
            
        } else {
            // Update one-time transaction
            transaction.status = .completed
            transaction.date = completionDate
            transaction.amount = finalAmount
            transaction.notes = notes
            
            // Update account balance
            if let account = transaction.account {
                if transaction.type == .income {
                    account.balance += finalAmount
                } else {
                    account.balance -= finalAmount
                }
            }
        }
        
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
} 