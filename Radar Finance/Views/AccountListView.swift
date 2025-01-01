import SwiftUI
import SwiftData

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @State private var showingAddAccount = false
    @State private var selectedAccount: Account?
    @State private var showingDeleteAlert = false
    @State private var accountToDelete: Account?
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(accounts) { account in
                AccountRowView(account: account)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedAccount = account
                    }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    accountToDelete = accounts[index]
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddAccount = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView()
        }
        .sheet(item: $selectedAccount) { account in
            EditAccountView(account: account)
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showingDeleteConfirmation = true
            }
        } message: {
            Text("Are you sure you want to delete this account? This will permanently delete all transactions associated with this account and cannot be undone.")
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            DeleteConfirmationView(
                isPresented: $showingDeleteConfirmation,
                title: "Confirm Delete",
                message: "This action cannot be undone. All transactions associated with this account will be permanently deleted.",
                onConfirm: {
                    if let account = accountToDelete {
                        deleteAccount(account)
                        if accounts.isEmpty {
                            dismiss()
                        }
                    }
                }
            )
        }
    }
    
    private func deleteAccount(_ account: Account) {
        // First handle any scheduled transactions
        let scheduledTransactions = transactions.filter { 
            $0.account?.id == account.id && 
            $0.schedule != nil 
        }
        
        // Delete schedules first to avoid orphaned schedules
        for transaction in scheduledTransactions {
            if let schedule = transaction.schedule {
                modelContext.delete(schedule)
                transaction.schedule = nil
            }
        }
        
        // The account and its associated transactions will be deleted automatically
        modelContext.delete(account)
        
        try? modelContext.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
} 