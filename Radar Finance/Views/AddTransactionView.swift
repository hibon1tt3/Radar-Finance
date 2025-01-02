import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    
    @State private var title = ""
    @State private var amountString = ""
    @State private var isEstimated = false
    @State private var selectedType: TransactionType
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var notes = ""
    @State private var isRecurring = false
    @State private var frequency = Frequency.monthly
    @State private var startDate = Date()
    @State private var showingAddCategory = false
    @State private var firstMonthlyDate = 1
    @State private var secondMonthlyDate = 15
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var showingNoAccountAlert = false
    @State private var navigateToAccounts = false
    
    let transactionType: TransactionType
    
    init(transactionType: TransactionType = .expense) {
        self._selectedType = State(initialValue: transactionType)
        self.transactionType = transactionType
    }
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault }
    }
    
    private var safeAmount: Decimal? {
        guard let amount = Decimal(string: amountString.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return amount.isNaN || amount.isInfinite ? nil : amount
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if accounts.isEmpty {
                    Section {
                        Text("Please add an account before creating transactions")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Transaction Details") {
                        CustomTextField(text: $title, placeholder: "Title")
                            .textInputAutocapitalization(.words)
                        
                        HStack {
                            Text("$")
                            CustomTextField(
                                text: $amountString,
                                placeholder: "Amount",
                                keyboardType: .decimalPad
                            )
                        }
                        
                        if selectedType == .expense {
                            Toggle("Estimated Amount", isOn: $isEstimated)
                        }
                        
                        Picker("Category", selection: $selectedCategory) {
                            Text("None").tag(nil as Category?)
                            ForEach(Category.categories(for: selectedType)) { category in
                                Label(category.rawValue, systemImage: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                    .tag(category as Category?)
                            }
                        }
                        
                        Picker("Account", selection: $selectedAccount) {
                            Text("None").tag(nil as Account?)
                            ForEach(accounts) { account in
                                Text(account.name).tag(account as Account?)
                            }
                        }
                        
                        // Show due date picker only if not recurring
                        if !isRecurring {
                            DatePicker(
                                "Due Date",
                                selection: $dueDate,
                                displayedComponents: .date
                            )
                        }
                    }
                    
                    Section("Schedule") {
                        Toggle("Recurring Transaction", isOn: $isRecurring)
                        
                        if isRecurring {
                            Picker("Frequency", selection: $frequency) {
                                ForEach([Frequency.weekly, .biweekly, .monthly, .twiceMonthly, .annual]) { frequency in
                                    Text(frequency.description).tag(frequency)
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
                        CustomTextEditor(text: $notes)
                            .frame(height: 100)
                    }
                }
            }
            .navigationTitle(transactionType == .income ? "New Income" : "New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        if !accounts.isEmpty {
                            saveTransaction()
                        }
                    }
                    .disabled(accounts.isEmpty || safeAmount == nil || selectedAccount == nil)
                }
            }
            .navigationDestination(isPresented: $navigateToAccounts) {
                AccountListView()
            }
            .onAppear {
                if selectedAccount == nil {
                    selectedAccount = defaultAccount
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                      to: nil, from: nil, for: nil)
    }
    
    private func saveTransaction() {
        guard !accounts.isEmpty else { return }
        guard let amount = Decimal(string: amountString) else { return }
        
        let schedule: Schedule?
        if isRecurring {
            schedule = Schedule(
                frequency: frequency,
                startDate: startDate,
                firstMonthlyDate: frequency == .twiceMonthly ? firstMonthlyDate : nil,
                secondMonthlyDate: frequency == .twiceMonthly ? secondMonthlyDate : nil
            )
        } else {
            schedule = Schedule(
                frequency: .once,
                startDate: dueDate,
                firstMonthlyDate: nil,
                secondMonthlyDate: nil
            )
        }
        
        let transaction = Transaction(
            title: title,
            amount: amount,
            isEstimated: isEstimated,
            category: selectedCategory,
            account: selectedAccount,
            type: transactionType,
            schedule: schedule,
            status: .pending,
            date: Date(),
            notes: notes.isEmpty ? nil : notes
        )
        
        modelContext.insert(transaction)
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
} 