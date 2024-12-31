import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    var id: String { rawValue }
} 