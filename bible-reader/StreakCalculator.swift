import Foundation

/// Pure streak math over the set of completed day keys.
enum StreakCalculator {
    static func streak(completedDayKeys: Set<String>, today: Date,
                       calendar: Calendar = .current) -> Int {
        var count = 0
        var cursor = today
        // If today isn't complete yet, measure the run ending yesterday.
        if !completedDayKeys.contains(DayKey.key(for: cursor, calendar: calendar)) {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = prev
        }
        while completedDayKeys.contains(DayKey.key(for: cursor, calendar: calendar)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }
}
