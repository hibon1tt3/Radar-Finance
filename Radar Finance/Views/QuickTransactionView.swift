import SwiftUI
import SwiftData
import Foundation

struct QuickTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var categories: [Category]
    
    let transactionType: TransactionType
    
    @State private var title = ""
    @State private var amountString = ""
    @State private var date = Date()
    @State private var categorySelection: CategorySelection = .none
    @State private var selectedAccount: Account?
    @State private var notes = ""
    @State private var showingAddCategory = false
    @State private var navigateToAccounts = false
    @State private var showingCamera = false
    @State private var receiptImage: UIImage?
    
    @EnvironmentObject private var cameraManager: CameraPermissionManager
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault } ?? accounts.first
    }
    
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
    
    var body: some View {
        NavigationStack {
            VStack {
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
                            
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                            
                            Picker("Category", selection: $categorySelection) {
                                Text("None").tag(CategorySelection.none)
                                Text("New Category").tag(CategorySelection.new)
                                
                                ForEach(categories.filter { $0.type == transactionType }) { category in
                                    HStack {
                                        Label(category.name, systemImage: category.icon)
                                            .foregroundColor(Color(hex: category.color))
                                    }.tag(CategorySelection.existing(category))
                                }
                            }
                            .onChange(of: categorySelection) { oldValue, newValue in
                                if case .new = newValue {
                                    showingAddCategory = true
                                    // Reset selection to previous value
                                    categorySelection = oldValue
                                }
                            }
                            
                            if !accounts.isEmpty {
                                let accountBinding = Binding(
                                    get: { selectedAccount ?? defaultAccount ?? accounts[0] },
                                    set: { selectedAccount = $0 }
                                )
                                
                                Picker("Account", selection: accountBinding) {
                                    ForEach(accounts) { account in
                                        Text(account.name).tag(account)
                                    }
                                }
                            }
                        }
                        
                        if cameraManager.isCameraAvailable {
                            Section("Receipt") {
                                if let image = receiptImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 200)
                                }
                                
                                Button(action: {
                                    showingCamera = true
                                }) {
                                    Label(
                                        receiptImage == nil ? "Take Photo" : "Retake Photo",
                                        systemImage: "camera"
                                    )
                                }
                            }
                        }
                        
                        Section("Notes") {
                            CustomTextEditor(text: $notes)
                                .frame(height: 100)
                        }
                    }
                }
                
                // Bottom button
                Button(action: saveTransaction) {
                    Text(transactionType == .income ? "Mark as Received" : "Mark as Paid")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(transactionType == .income ? Color.green : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(title.isEmpty || amountString.isEmpty)
                .padding()
            }
            .navigationTitle(transactionType == .income ? "Quick Income" : "Quick Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(presetType: transactionType)
                    .modelContainer(modelContext.container)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $receiptImage)
                    .ignoresSafeArea()
            }
            .onAppear {
                if selectedAccount == nil && !accounts.isEmpty {
                    selectedAccount = defaultAccount ?? accounts[0]
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amount = Decimal(string: amountString),
              !amount.isNaN && !amount.isInfinite else { return }
        
        let imageData = receiptImage?.jpegData(compressionQuality: 0.8)
        
        let transaction = Transaction(
            title: title,
            amount: amount,
            isEstimated: false,
            category: categorySelection.category,
            account: selectedAccount,
            type: transactionType,
            schedule: nil,
            status: .completed,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            receiptImage: imageData
        )
        
        // Update account balance
        if let account = selectedAccount {
            if transactionType == .income {
                account.balance += amount
            } else {
                account.balance -= amount
            }
        }
        
        modelContext.insert(transaction)
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
} 