import Foundation
import SwiftData

@Model
final class Schedule {
    var frequency: Frequency
    var startDate: Date
    var lastProcessed: Date?
    var firstMonthlyDate: Int?  // Day of month (1-31)
    var secondMonthlyDate: Int? // Day of month (1-31)
    
    init(
        frequency: Frequency, 
        startDate: Date,
        firstMonthlyDate: Int? = nil,
        secondMonthlyDate: Int? = nil
    ) {
        self.frequency = frequency
        self.startDate = startDate
        self.firstMonthlyDate = firstMonthlyDate
        self.secondMonthlyDate = secondMonthlyDate
    }
}

enum Frequency: String, Codable, Identifiable {
    case oneTime
    case weekly
    case biweekly
    case monthly
    case twiceMonthly
    case annual
    case once
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .oneTime: return "One Time"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-Weekly"
        case .monthly: return "Monthly"
        case .twiceMonthly: return "Twice Monthly"
        case .annual: return "Annual"
        case .once: return "Once"
        }
    }
}

extension Schedule {
    func nextOccurrence(after date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        
        switch frequency {
        case .once, .oneTime:  // Handle both once and oneTime
            return startDate > startOfToday ? startDate : nil
            
        case .weekly:
            let startOfStartDate = calendar.startOfDay(for: startDate)
            let startOfTodayDate = startOfToday
            print("Weekly Debug:")
            print("Start Date: \(startDate)")
            print("Today: \(date)")
            print("Start of Start Date: \(startOfStartDate)")
            print("Start of Today: \(startOfTodayDate)")
            print("Comparison Result: \(startOfStartDate > startOfTodayDate)")
            
            // If start date is in future, use it
            if startOfStartDate > startOfTodayDate {
                print("Using future start date: \(startDate)")
                return startDate
            }
            
            // Otherwise find next occurrence
            var next = startDate
            while calendar.startOfDay(for: next) < startOfToday {
                let previous = next
                next = calendar.date(byAdding: .day, value: 7, to: next) ?? next
                print("Advancing date from \(previous) to \(next)")
            }
            print("Final next date: \(next)")
            return next
            
        case .biweekly:
            let startOfStartDate = calendar.startOfDay(for: startDate)
            let startOfTodayDate = startOfToday
            print("Biweekly Debug:")
            print("Start Date: \(startDate)")
            print("Today: \(date)")
            print("Start of Start Date: \(startOfStartDate)")
            print("Start of Today: \(startOfTodayDate)")
            print("Comparison Result: \(startOfStartDate > startOfTodayDate)")
            
            // If start date is in future, use it
            if startOfStartDate > startOfTodayDate {
                print("Using future start date: \(startDate)")
                return startDate
            }
            
            // Otherwise find next occurrence
            var next = startDate
            while calendar.startOfDay(for: next) < startOfToday {
                let previous = next
                next = calendar.date(byAdding: .day, value: 14, to: next) ?? next
                print("Advancing date from \(previous) to \(next)")
            }
            print("Final next date: \(next)")
            return next
            
        case .monthly:
            var next = startDate
            while calendar.startOfDay(for: next) <= startOfToday {
                next = calendar.date(byAdding: .month, value: 1, to: next) ?? next
            }
            return next
            
        case .twiceMonthly:
            guard let firstDate = firstMonthlyDate,
                  let secondDate = secondMonthlyDate else { return nil }
            
            let day = calendar.component(.day, from: date)
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            
            // If we're before the first date of the month
            if day < firstDate {
                return calendar.date(from: DateComponents(year: year, month: month, day: firstDate))
            }
            // If we're between the first and second dates
            else if day < secondDate {
                return calendar.date(from: DateComponents(year: year, month: month, day: secondDate))
            }
            // If we're after the second date, move to first date of next month
            else {
                return calendar.date(from: DateComponents(year: year, month: month + 1, day: firstDate))
            }
            
        case .annual:
            var next = startDate
            while calendar.startOfDay(for: next) <= startOfToday {
                next = calendar.date(byAdding: .year, value: 1, to: next) ?? next
            }
            return next
        }
    }
} 