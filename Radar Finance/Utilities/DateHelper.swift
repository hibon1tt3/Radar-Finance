import Foundation

struct DateHelper {
    static let calendar = Calendar.current
    
    static func generateOccurrences(for schedule: Schedule, startingFrom: Date, endDate: Date) -> [Date] {
        let calendar = Calendar.current
        var occurrences: [Date] = []
        
        switch schedule.frequency {
        case .weekly:
            var current = schedule.startDate
            while current <= endDate {
                if current >= startingFrom {
                    occurrences.append(current)
                }
                current = calendar.date(byAdding: .day, value: 7, to: current) ?? current
            }
            
        case .biweekly:
            var current = schedule.startDate
            while current <= endDate {
                if current >= startingFrom {
                    occurrences.append(current)
                }
                current = calendar.date(byAdding: .day, value: 14, to: current) ?? current
            }
            
        case .monthly:
            var current = schedule.startDate
            while current <= endDate {
                if current >= startingFrom {
                    // Handle months without the same day (e.g., 31st)
                    let targetDay = calendar.component(.day, from: schedule.startDate)
                    var components = calendar.dateComponents([.year, .month], from: current)
                    components.day = targetDay
                    
                    if let adjusted = calendar.date(from: components) {
                        // If the target date doesn't exist (e.g., Feb 31), use last day of month
                        let actualDate = adjusted > current ? 
                            calendar.date(byAdding: .day, value: -1, to: adjusted) ?? current : 
                            adjusted
                        occurrences.append(actualDate)
                    }
                }
                current = calendar.date(byAdding: .month, value: 1, to: current) ?? current
            }
            
        case .twiceMonthly:
            // Start with next month since current month's dates are past
            let currentDate = startingFrom
            
            if let firstDay = schedule.firstMonthlyDate,
               let secondDay = schedule.secondMonthlyDate {
                var components = DateComponents()
                
                // Generate dates for the next 3 months to ensure we cover the 30-day window
                for monthOffset in 0...2 {
                    let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
                    let targetMonth = calendar.component(.month, from: targetDate)
                    let targetYear = calendar.component(.year, from: targetDate)
                    
                    components.year = targetYear
                    components.month = targetMonth
                    
                    // First date of month
                    components.day = firstDay
                    if let firstDate = calendar.date(from: components) {
                        if firstDate >= startingFrom && firstDate <= endDate {
                            occurrences.append(firstDate)
                        }
                    }
                    
                    // Second date of month
                    components.day = secondDay
                    if let secondDate = calendar.date(from: components) {
                        if secondDate >= startingFrom && secondDate <= endDate {
                            occurrences.append(secondDate)
                        }
                    }
                }
            }
            
        case .annual:
            var current = schedule.startDate
            while current <= endDate {
                if current >= startingFrom {
                    occurrences.append(current)
                }
                current = calendar.date(byAdding: .year, value: 1, to: current) ?? current
            }
            
        case .oneTime:
            if schedule.startDate >= startingFrom && schedule.startDate <= endDate {
                occurrences.append(schedule.startDate)
            }
            
        case .once:
            if schedule.startDate >= startingFrom && schedule.startDate <= endDate {
                occurrences.append(schedule.startDate)
            }
        }
        
        return occurrences.sorted()
    }
    
    static func nextOccurrence(for frequency: Frequency, after date: Date, startDate: Date, firstMonthlyDate: Int? = nil, secondMonthlyDate: Int? = nil) -> Date? {
        switch frequency {
        case .once, .oneTime:
            // For one-time events, there is no next occurrence
            return nil
            
        case .weekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: date)
            
        case .biweekly:
            return Calendar.current.date(byAdding: .weekOfYear, value: 2, to: date)
            
        case .monthly:
            return Calendar.current.date(byAdding: .month, value: 1, to: date)
            
        case .twiceMonthly:
            guard let firstDate = firstMonthlyDate,
                  let secondDate = secondMonthlyDate else {
                return Calendar.current.date(byAdding: .month, value: 1, to: date)
            }
            
            let currentDay = Calendar.current.component(.day, from: date)
            if currentDay < secondDate {
                // Next occurrence is the second date of this month
                return date.setDay(secondDate)
            } else {
                // Next occurrence is the first date of next month
                if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: date) {
                    return nextMonth.setDay(firstDate)
                }
            }
            return nil
            
        case .annual:
            return Calendar.current.date(byAdding: .year, value: 1, to: date)
        }
    }
} 