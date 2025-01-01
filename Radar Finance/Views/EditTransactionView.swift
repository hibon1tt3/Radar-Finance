import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var transaction: Transaction
    
    @State private var title: String
    @State private var amountString: String
    @State private var isEstimated: Bool
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var notes: String
    @State private var isRecurring: Bool
    @State private var frequency: Frequency
    @State private var startDate: Date
    @State private var firstMonthlyDate: Int
    @State private var secondMonthlyDate: Int
    @State private var showingAddCategory = false
    @State private var categorySelection: CategorySelection
    
    @Query private var categories: [Category]
    @Query private var accounts: [Account]
    
    enum CategorySelection: Hashable {
        case none
        case new
        case existing(Category)
        
        var category: Category? {
            if case .existing(let category) = self {
                return category
            }
            return nil
        }
    }
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _title = State(initialValue: transaction.title)
        _amountString = State(initialValue: transaction.amount.formatted())
        _isEstimated = State(initialValue: transaction.isEstimated)
        _selectedCategory = State(initialValue: transaction.category)
        _selectedAccount = State(initialValue: transaction.account)
        _notes = State(initialValue: transaction.notes ?? "")
        _isRecurring = State(initialValue: transaction.schedule?.frequency != .once)
        _frequency = State(initialValue: transaction.schedule?.frequency ?? .monthly)
        _startDate = State(initialValue: transaction.schedule?.startDate ?? Date())
        _firstMonthlyDate = State(initialValue: transaction.schedule?.firstMonthlyDate ?? 1)
        _secondMonthlyDate = State(initialValue: transaction.schedule?.secondMonthlyDate ?? 15)
        
        if let category = transaction.category {
            _categorySelection = State(initialValue: .existing(category))
        } else {
            _categorySelection = State(initialValue: .none)
        }
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
                    
                    if transaction.type == .expense {
                        Toggle("Estimated Amount", isOn: $isEstimated)
                    }
                    
                    Picker("Category", selection: $categorySelection) {
                        Text("None").tag(CategorySelection.none)
                        Text("New Category").tag(CategorySelection.new)
                        
                        ForEach(categories.filter { $0.type == transaction.type }) { category in
                            HStack {
                                Label(category.name, systemImage: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                            }.tag(CategorySelection.existing(category))
                        }
                    }
                    .onChange(of: categorySelection) { oldValue, newValue in
                        if case .new = newValue {
                            showingAddCategory = true
                            categorySelection = oldValue
                        }
                        selectedCategory = newValue.category
                    }
                    
                    Picker("Account", selection: $selectedAccount) {
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
            .navigationTitle(transaction.type == .income ? "Edit Income" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(safeAmount == nil)
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(presetType: transaction.type)
            }
        }
    }
    
    private func saveChanges() {
        guard let amount = safeAmount else { return }
        
        // Update transaction properties
        transaction.title = title
        transaction.amount = amount
        transaction.isEstimated = isEstimated
        transaction.category = selectedCategory
        
        // Handle account changes
        let oldAccount = transaction.account
        transaction.account = selectedAccount
        
        // Update account balances if needed
        if oldAccount != selectedAccount {
            if transaction.type == .income {
                oldAccount?.balance -= amount
                selectedAccount?.balance += amount
            } else {
                oldAccount?.balance += amount
                selectedAccount?.balance -= amount
            }
        }
        
        // Update schedule
        if isRecurring {
            transaction.schedule = Schedule(
                frequency: frequency,
                startDate: startDate,
                firstMonthlyDate: frequency == .twiceMonthly ? firstMonthlyDate : nil,
                secondMonthlyDate: frequency == .twiceMonthly ? secondMonthlyDate : nil
            )
        } else {
            transaction.schedule = nil
        }
        
        transaction.notes = notes.isEmpty ? nil : notes
        
        try? modelContext.save()
        dismiss()
    }
} 