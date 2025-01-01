import SwiftData
import SwiftUI

struct CategoryService {
    static func createSystemCategories(in context: ModelContext) {
        // Check if system categories already exist
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { category in
                category.isSystem == true
            }
        )
        
        guard let existingCount = try? context.fetch(descriptor).count,
              existingCount < Category.systemCategories.count else {
            return // All system categories already exist
        }
        
        // Create system categories
        for systemCategory in Category.systemCategories {
            let category = Category(
                name: systemCategory.name,
                type: systemCategory.type,
                icon: systemCategory.icon,
                color: systemCategory.color,
                isSystem: true  // Mark as system category
            )
            context.insert(category)
        }
        
        try? context.save()
    }
} 