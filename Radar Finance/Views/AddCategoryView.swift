import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type: TransactionType
    @State private var icon = "tag"
    @State private var color = "#007AFF"
    
    let presetType: TransactionType?
    
    init(presetType: TransactionType? = nil) {
        self.presetType = presetType
        _type = State(initialValue: presetType ?? .expense)
    }
    
    let icons = [
        "dollarsign.circle.fill",     // General money
        "creditcard.fill",            // Credit/Payment
        "building.columns.fill",       // Banking/Financial institutions
        "chart.line.uptrend.xyaxis",  // Investments/Stocks
        "house.fill",                 // Housing/Property
        "car.fill",                   // Transportation
        "cart.fill",                  // Shopping
        "fork.knife",                 // Food/Dining
        "cross.fill",                 // Medical/Health
        "heart.fill",                 // Charity/Personal
        "tv.fill",                    // Entertainment
        "airplane",                   // Travel
        "graduationcap.fill",         // Education
        "briefcase.fill",             // Business/Work
        "gift.fill",                  // Gifts
        "wrench.fill",                // Services/Repairs
        "wifi",                       // Utilities/Internet
        "phone.fill",                 // Phone/Communications
        "leaf.fill",                  // Environment/Utilities
        "doc.text.fill",              // Bills/Documents
        "percent",                    // Interest/Percentages
        "repeat",                     // Subscriptions/Recurring
        "arrow.counterclockwise",     // Refunds/Returns
        "ellipsis.circle.fill"        // Miscellaneous
    ]
    
    let colors = [
        "#007AFF", // Blue
        "#34C759", // Green
        "#FF3B30", // Red
        "#FF9500", // Orange
        "#FF2D55", // Pink
        "#5856D6", // Purple
        "#AF52DE", // Magenta
        "#000000", // Black
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    CustomTextField(text: $name, placeholder: "Name")
                        .textInputAutocapitalization(.words)
                    
                    if presetType == nil {
                        Picker("Type", selection: $type) {
                            Text("Expense").tag(TransactionType.expense)
                            Text("Income").tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
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
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveCategory() {
        let category = Category(
            name: name,
            type: type,
            icon: icon,
            color: color
        )
        
        modelContext.insert(category)
        try? modelContext.save()
        dismiss()
    }
} 