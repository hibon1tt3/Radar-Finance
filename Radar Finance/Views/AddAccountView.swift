import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    
    @State private var name = ""
    @State private var type = AccountType.checking
    @State private var balanceString = ""
    @State private var icon = "banknote"
    @State private var color = "#34C759"
    @State private var isDefault = false
    
    let icons = [
        "banknote",
        "creditcard",
        "building.columns",
        "chart.line.uptrend.xyaxis",
        "dollarsign.circle",
        "house",
        "lock",
        "percent"
    ]
    
    let colors = [
        "#34C759", // Green
        "#007AFF", // Blue
        "#FF9500", // Orange
        "#FF3B30", // Red
        "#5856D6", // Purple
        "#FF2D55", // Pink
        "#AF52DE", // Magenta
        "#000000", // Black
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    CustomTextField(text: $name, placeholder: "Name")
                        .textInputAutocapitalization(.words)
                    
                    Picker("Type", selection: $type) {
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
                            placeholder: "Initial Balance",
                            keyboardType: .decimalPad
                        )
                    }
                    
                    Toggle("Set as Default Account", isOn: $isDefault)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(icons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(icon == iconName ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    icon = iconName
                                }
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(colors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: color == colorHex ? 2 : 0)
                                )
                                .onTapGesture {
                                    color = colorHex
                                }
                        }
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .disabled(name.isEmpty || balanceString.isEmpty)
                }
            }
            .onAppear {
                if accounts.isEmpty {
                    isDefault = true
                }
            }
        }
        .environment(\.sizeCategory, .medium)
        .dynamicTypeSize(.medium)
    }
    
    private func saveAccount() {
        guard let balance = Decimal(string: balanceString) else { return }
        
        let account = Account(
            name: name,
            type: type,
            balance: balance,
            icon: icon,
            color: color,
            isDefault: isDefault,
            startingBalance: balance
        )
        
        modelContext.insert(account)
        try? modelContext.save()
        dismiss()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                      to: nil, from: nil, for: nil)
    }
} 