import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @EnvironmentObject private var cameraManager: CameraPermissionManager
    @Bindable var transaction: Transaction
    
    @State private var amountString: String
    @State private var selectedAccount: Account?
    @State private var completionDate: Date
    @State private var showingCamera = false
    @State private var showingImage = false
    @State private var receiptImage: UIImage?
    
    init(transaction: Transaction) {
        self.transaction = transaction
        self._amountString = State(initialValue: String(describing: transaction.amount))
        self._selectedAccount = State(initialValue: transaction.account)
        self._completionDate = State(initialValue: transaction.date)
        
        if let imageData = transaction.receiptImage,
           let image = UIImage(data: imageData) {
            self._receiptImage = State(initialValue: image)
        }
    }
    
    var body: some View {
        NavigationStack {
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
                    HStack {
                        Text("$")
                        CustomTextField(
                            text: $amountString,
                            placeholder: "Amount",
                            keyboardType: .decimalPad
                        )
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
                            Button(action: { showingImage = true }) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                            }
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
                
                if let notes = transaction.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                    }
                }
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: updateTransaction) {
                    Text("Update Transaction")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(transaction.type == .expense ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
        }
        .environment(\.sizeCategory, .medium)
        .dynamicTypeSize(.medium)
        .environment(\.legibilityWeight, .regular)
        .fontWeight(.regular)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(image: $receiptImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingImage) {
            if let image = receiptImage {
                NavigationStack {
                    ZoomableImageView(image: image)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingImage = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func updateTransaction() {
        // Update amount if valid
        if let newAmount = Decimal(string: amountString) {
            // Handle account balance updates
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
                        newAccount.balance += newAmount
                    } else {
                        newAccount.balance -= newAmount
                    }
                }
                
                transaction.account = selectedAccount
            } else {
                // Update balance for the same account with new amount
                if let account = selectedAccount {
                    if transaction.type == .income {
                        account.balance += (newAmount - transaction.amount)
                    } else {
                        account.balance -= (newAmount - transaction.amount)
                    }
                }
            }
            
            transaction.amount = newAmount
        }
        
        transaction.date = completionDate
        transaction.receiptImage = receiptImage?.jpegData(compressionQuality: 0.8)
        
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}

// Add this helper view for zooming functionality
struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var magnifyBy = CGFloat(1.0)
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: geometry.size.width)
                .scaleEffect(scale * magnifyBy)
                .gesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { currentState, gestureState, _ in
                            gestureState = currentState
                        }
                        .onEnded { value in
                            scale *= value
                            scale = min(max(scale, 1), 4) // Limit zoom between 1x and 4x
                        }
                )
        }
        .background(Color(.systemBackground))
    }
} 