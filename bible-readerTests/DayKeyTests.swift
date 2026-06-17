import Testing
import Foundation
@testable import bible_reader

struct DayKeyTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test func formatsZeroPaddedYearMonthDay() {
        // 2026-06-07 00:00:00 UTC
        let date = Date(timeIntervalSince1970: 1_780_790_400)
        #expect(DayKey.key(for: date, calendar: utc) == "2026-06-07")
    }

    @Test func respectsCalendarTimeZone() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 2026-06-17 23:30 UTC is already 2026-06-18 in Tokyo (+9).
        let date = Date(timeIntervalSince1970: 1_781_739_000)
        #expect(DayKey.key(for: date, calendar: utc) == "2026-06-17")
        #expect(DayKey.key(for: date, calendar: tokyo) == "2026-06-18")
    }
}
