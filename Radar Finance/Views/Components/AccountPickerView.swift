import SwiftUI
import SwiftData

struct AccountPickerView: View {
    @Binding var selectedAccount: Account?
    @Query(sort: \Account.name) private var accounts: [Account]
    var showAllAccounts: Bool = false
    
    private var defaultAccount: Account? {
        accounts.first { $0.isDefault } ?? accounts.first
    }
    
    var body: some View {
        HStack {
            Text("Select Account")
                .foregroundColor(.secondary)
            Spacer()
            if accounts.isEmpty {
                Text("No Accounts")
                    .foregroundColor(.secondary)
            } else {
                // Create a binding that ensures we always have a selection
                let binding = Binding(
                    get: { selectedAccount ?? defaultAccount ?? accounts[0] },
                    set: { selectedAccount = $0 }
                )
                
                Picker("", selection: binding) {
                    ForEach(accounts) { account in
                        Text(account.name).tag(account)
                    }
                }
                .pickerStyle(.menu)
                .tint(.blue)
            }
        }
        .onAppear {
            // Ensure we have a selection on appear
            if selectedAccount == nil && !accounts.isEmpty {
                selectedAccount = defaultAccount ?? accounts[0]
            }
        }
        .onChange(of: accounts) { oldValue, newValue in
            // If accounts change and our selection is invalid, update it
            if !newValue.isEmpty && (selectedAccount == nil || !newValue.contains(where: { $0.id == selectedAccount?.id })) {
                selectedAccount = defaultAccount ?? newValue[0]
            }
        }
    }
} 