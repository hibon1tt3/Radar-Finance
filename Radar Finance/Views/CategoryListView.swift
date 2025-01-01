import SwiftUI
import SwiftData

struct CategoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]
    @Query private var transactions: [Transaction]
    @State private var showingAddCategory = false
    @State private var selectedCategory: Category?
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: Category?
    
    var body: some View {
        List {
            Section("Income Categories") {
                ForEach(categories.filter { $0.type == .income }) { category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = category
                        }
                }
                .onDelete { indexSet in
                    let incomeCategories = categories.filter { $0.type == .income }
                    for index in indexSet {
                        let category = incomeCategories[index]
                        if !category.isSystem {  // Only allow deletion of non-system categories
                            categoryToDelete = category
                            showingDeleteAlert = true
                        }
                    }
                }
            }
            
            Section("Expense Categories") {
                ForEach(categories.filter { $0.type == .expense }) { category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCategory = category
                        }
                }
                .onDelete { indexSet in
                    let expenseCategories = categories.filter { $0.type == .expense }
                    for index in indexSet {
                        let category = expenseCategories[index]
                        if !category.isSystem {  // Only allow deletion of non-system categories
                            categoryToDelete = category
                            showingDeleteAlert = true
                        }
                    }
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddCategory = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
        .sheet(item: $selectedCategory) { category in
            EditCategoryView(category: category)
        }
        .alert("Delete Category", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    deleteCategory(category)
                }
            }
        } message: {
            Text("Are you sure you want to delete this category? All transactions with this category will have their category set to none.")
        }
    }
    
    private func deleteCategory(_ category: Category) {
        // Update all transactions that use this category
        for transaction in transactions {
            if transaction.category?.id == category.id {
                transaction.category = nil
            }
        }
        
        // Delete the category
        modelContext.delete(category)
        try? modelContext.save()
    }
}

struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(Color(hex: category.color))
                .frame(width: 32)
            
            Text(category.name)
            
            if category.isSystem {
                Spacer()
                Text("System")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
} 