import Foundation

struct TransactionOccurrence: Identifiable {
    let id = UUID()
    let transaction: Transaction?
    let dueDate: Date
    private let _amount: Decimal
    
    var amount: Decimal {
        return _amount.isNaN || _amount.isInfinite ? Decimal.zero : _amount
    }
    
    let isCompleted: Bool
    
    init(transaction: Transaction?, dueDate: Date, amount: Decimal, isCompleted: Bool = false) {
        self.transaction = transaction
        self.dueDate = dueDate
        self._amount = amount.isNaN || amount.isInfinite ? Decimal.zero : amount
        self.isCompleted = isCompleted
    }
} 