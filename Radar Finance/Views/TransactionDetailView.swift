import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction
    @State private var showingImage = false // For full-screen image view
    @State private var showingDeleteAlert = false
    @EnvironmentObject private var viewModel: AppState
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(transaction.title)
                        .font(.headline)
                    
                    if let category = transaction.category {
                        Label(category.name, systemImage: category.icon)
                            .foregroundColor(Color(hex: category.color))
                    }
                }
                
                Section {
                    LabeledContent("Amount") {
                        Text(transaction.amount.formatted(.currency(code: "USD")))
                            .foregroundColor(transaction.type == .income ? .green : .red)
                    }
                    
                    LabeledContent("Date") {
                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    }
                    
                    if let account = transaction.account {
                        LabeledContent("Account") {
                            Text(account.name)
                        }
                    }
                }
                
                if let notes = transaction.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                    }
                }
                
                if let imageData = transaction.receiptImage,
                   let uiImage = UIImage(data: imageData) {
                    Section("Receipt") {
                        Button(action: { showingImage = true }) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                
                Section {
                    Button("Delete Transaction", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle(transaction.type == .income ? "Income Details" : "Expense Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingImage) {
            if let imageData = transaction.receiptImage,
               let uiImage = UIImage(data: imageData) {
                NavigationStack {
                    ZoomableImageView(image: uiImage)
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
        .alert("Delete Transaction", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTransactionView(transaction: transaction)
        }
    }
    
    private func deleteTransaction() {
        Task {
            do {
                // First delete from CloudKit
                let success = try await CloudKitSyncService.shared.handleModelDeletion(transaction)
                
                if success {
                    // Revert the balance change
                    if let account = transaction.account {
                        if transaction.type == .income {
                            account.balance -= transaction.amount
                        } else {
                            account.balance += transaction.amount
                        }
                    }
                    
                    // Then delete locally
                    modelContext.delete(transaction)
                    try? modelContext.save()
                    HapticManager.shared.notification(type: .success)
                    dismiss()
                }
            } catch {
                print("Failed to delete transaction: \(error)")
                // Show error to user
            }
        }
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

struct CategoryPicker: View {
    @Binding var selectedCategory: Category?
    @Query private var categories: [Category]
    let transactionType: TransactionType
    
    var body: some View {
        Picker("Category", selection: $selectedCategory) {
            Text("None").tag(nil as Category?)
            
            // Show both system and custom categories, grouped by type
            ForEach(categories.filter { $0.type == transactionType }) { category in
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Color(hex: category.color))
                    Text(category.name)
                    if category.isSystem {
                        Spacer()
                        Text("System")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }.tag(category as Category?)
            }
        }
    }
} 