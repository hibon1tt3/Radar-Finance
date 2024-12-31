import Foundation

extension Decimal {
    func rounded(_ places: Int = 0) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, places, .plain)
        return result
    }
} 