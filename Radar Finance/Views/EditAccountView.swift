import SwiftUI
import SwiftData

struct EditAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    
    @Bindable var account: Account
    @State private var balanceString: String
    
    init(account: Account) {
        self.account = account
        self._balanceString = State(initialValue: String(describing: account.balance))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    CustomTextField(text: $account.name, placeholder: "Name")
                        .textInputAutocapitalization(.words)
                    
                    Picker("Type", selection: $account.type) {
                        Text("Checking").tag(AccountType.checking)
                        Text("Savings").tag(AccountType.savings)
                        Text("Credit").tag(AccountType.credit)
                        Text("Investment").tag(AccountType.investment)
                        Text("Other").tag(AccountType.other)
                    }
                    
                    HStack {
                        Text("$")
                        CustomTextField(
                            text: $balanceString,
                            placeholder: "Balance",
                            keyboardType: .decimalPad
                        )
                    }
                    .onChange(of: balanceString) { _, newValue in
                        if let balance = Decimal(string: newValue) {
                            account.balance = balance
                        }
                    }
                    
                    Toggle("Set as Default Account", isOn: $account.isDefault)
                        .onChange(of: account.isDefault) { oldValue, newValue in
                            if newValue {
                                for otherAccount in accounts where otherAccount.id != account.id {
                                    otherAccount.isDefault = false
                                }
                            }
                        }
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach([
                            "banknote",
                            "creditcard",
                            "building.columns",
                            "chart.line.uptrend.xyaxis",
                            "dollarsign.circle",
                            "house",
                            "lock",
                            "percent"
                        ], id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(account.icon == iconName ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    account.icon = iconName
                                }
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach([
                            "#34C759", // Green
                            "#007AFF", // Blue
                            "#FF9500", // Orange
                            "#FF3B30", // Red
                            "#5856D6", // Purple
                            "#FF2D55", // Pink
                            "#AF52DE", // Magenta
                            "#000000", // Black
                        ], id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: account.color == colorHex ? 2 : 0)
                                )
                                .onTapGesture {
                                    account.color = colorHex
                                }
                        }
                    }
                }
            }
            .navigationTitle("Edit Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(account.name.isEmpty)
                }
            }
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                // First, delete all associated transactions from CloudKit
                for transaction in account.transactions {
                    let success = try await CloudKitSyncService.shared.handleModelDeletion(transaction)
                    if success {
                        modelContext.delete(transaction)
                    } else {
                        print("Failed to delete transaction: \(transaction.title)")
                    }
                }
                
                // Then delete the account from CloudKit
                let success = try await CloudKitSyncService.shared.handleModelDeletion(account)
                
                if success {
                    modelContext.delete(account)
                    try modelContext.save()
                    dismiss()
                } else {
                    print("Failed to delete account from CloudKit")
                }
            } catch {
                print("Error deleting account: \(error)")
            }
        }
    }
} 