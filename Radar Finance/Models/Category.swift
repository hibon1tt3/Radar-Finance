import Foundation
import SwiftData

@Model
final class Category: Identifiable {
    var id: UUID
    var name: String
    var type: TransactionType
    var icon: String
    var color: String
    
    @Relationship(deleteRule: .cascade) var transactions: [Transaction]?
    
    init(
        id: UUID = UUID(),
        name: String,
        type: TransactionType,
        icon: String = "tag",
        color: String = "#007AFF"
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.color = color
    }
} 