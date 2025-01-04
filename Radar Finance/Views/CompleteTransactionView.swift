import SwiftUI
import SwiftData

struct CompleteTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @EnvironmentObject private var cameraManager: CameraPermissionManager
    @Bindable var transaction: Transaction
    let occurrenceDate: Date
    
    @State private var completionDate: Date = Date()
    @State private var actualAmountString: String = ""
    @State private var selectedAccount: Account?
    @State private var notes: String
    @State private var showingCamera = false
    @State private var receiptImage: UIImage?
    
    init(transaction: Transaction, occurrenceDate: Date) {
        self.transaction = transaction
        self.occurrenceDate = occurrenceDate
        self._selectedAccount = State(initialValue: transaction.account)
        self._actualAmountString = State(initialValue: transaction.isEstimated ? "" : String(describing: transaction.amount))
        self._notes = State(initialValue: transaction.notes ?? "")
        
        if let imageData = transaction.receiptImage,
           let image = UIImage(data: imageData) {
            self._receiptImage = State(initialValue: image)
        }
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
                            HStack {
                                Text("$")
                                CustomTextField(
                                    text: $actualAmountString,
                                    placeholder: "Amount",
                                    keyboardType: .decimalPad
                                )
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
                        
                        Picker("Account", selection: $selectedAccount) {
                            Text("None").tag(nil as Account?)
                            ForEach(accounts) { account in
                                Text(account.name).tag(account as Account?)
                            }
                        }
                    }
                    
                    if cameraManager.isCameraEnabled && cameraManager.isCameraAvailable {
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
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $receiptImage)
                    .ignoresSafeArea()
            }
        }
        .environment(\.sizeCategory, .medium)
        .dynamicTypeSize(.medium)
        .environment(\.legibilityWeight, .regular)
        .fontWeight(.regular)
    }
    
    private func completeTransaction() {
        // Get the final amount to use
        let finalAmount: Decimal
        if transaction.isEstimated {
            finalAmount = Decimal(string: actualAmountString) ?? transaction.amount
        } else {
            finalAmount = Decimal(string: actualAmountString) ?? transaction.amount
        }
        
        // Handle account balance updates for both old and new accounts
        if transaction.schedule != nil {
            // Create a new completed transaction
            let completedTransaction = Transaction(
                title: transaction.title,
                amount: finalAmount,
                isEstimated: false,
                category: transaction.category,
                account: selectedAccount,
                type: transaction.type,
                schedule: nil,
                status: .completed,
                date: completionDate,
                notes: notes,
                receiptImage: receiptImage?.jpegData(compressionQuality: 0.8)
            )
            
            modelContext.insert(completedTransaction)
            
            // Update account balance
            if let account = selectedAccount {
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
            transaction.receiptImage = receiptImage?.jpegData(compressionQuality: 0.8)
            
            // Handle account change if needed
            if transaction.account != selectedAccount {
                // Reverse the transaction from the old account
                if let oldAccount = transaction.account {
                    if transaction.type == .income {
                        oldAccount.balance -= transaction.amount
                    } else {
                        oldAccount.balance += transaction.amount
                    }
                }
                
                // Apply the transaction to the new account
                if let newAccount = selectedAccount {
                    if transaction.type == .income {
                        newAccount.balance += finalAmount
                    } else {
                        newAccount.balance -= finalAmount
                    }
                }
                
                transaction.account = selectedAccount
            } else {
                // Update balance for the same account with potentially new amount
                if let account = selectedAccount {
                    if transaction.type == .income {
                        account.balance += (finalAmount - transaction.amount)
                    } else {
                        account.balance -= (finalAmount - transaction.amount)
                    }
                }
            }
        }
        
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
} 