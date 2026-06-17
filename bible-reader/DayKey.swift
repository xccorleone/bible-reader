import Foundation

/// Local-calendar day identifier used to key reading sessions and streaks.
/// Built from calendar components (not DateFormatter) to avoid locale surprises.
enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
