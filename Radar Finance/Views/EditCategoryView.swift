import SwiftUI
import SwiftData

struct EditCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var category: Category
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    TextField("Name", text: $category.name)
                    
                    Picker("Type", selection: $category.type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(["tag", "cart", "house", "car", "bus", "tram", "airplane", 
                                "gift", "fork.knife", "heart", "cross", "pills", "creditcard", 
                                "banknote", "bag", "basketball", "bicycle", "book.closed", 
                                "display", "gamecontroller", "music.note", "hammer", 
                                "paintbrush", "phone"], id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(category.icon == iconName ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    category.icon = iconName
                                }
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach([
                            "#007AFF", // Blue
                            "#34C759", // Green
                            "#FF3B30", // Red
                            "#FF9500", // Orange
                            "#FF2D55", // Pink
                            "#5856D6", // Purple
                            "#AF52DE", // Magenta
                            "#000000", // Black
                        ], id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: category.color == colorHex ? 2 : 0)
                                )
                                .onTapGesture {
                                    category.color = colorHex
                                }
                        }
                    }
                }
            }
            .navigationTitle("Edit Category")
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
                    .disabled(category.name.isEmpty)
                }
            }
        }
    }
    
    private func deleteCategory() {
        Task {
            try? await CloudKitSyncService.shared.handleModelDeletion(category)
        }
        modelContext.delete(category)
        try? modelContext.save()
        dismiss()
    }
} 