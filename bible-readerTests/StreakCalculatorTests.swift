import Testing
import Foundation
@testable import bible_reader

struct StreakCalculatorTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    // 2026-06-17 12:00 UTC
    private let today = Date(timeIntervalSince1970: 1_781_697_600)

    @Test func countsTodayPlusPriorConsecutive() {
        let keys: Set<String> = ["2026-06-15", "2026-06-16", "2026-06-17"]
        #expect(StreakCalculator.streak(completedDayKeys: keys, today: today, calendar: utc) == 3)
    }

    @Test func todayIncompleteStillCountsPriorRun() {
        let keys: Set<String> = ["2026-06-15", "2026-06-16"]   // today (17) missing
        #expect(StreakCalculator.streak(completedDayKeys: keys, today: today, calendar: utc) == 2)
    }

    @Test func stopsAtGap() {
        let keys: Set<String> = ["2026-06-17", "2026-06-15"]   // 16 missing
        #expect(StreakCalculator.streak(completedDayKeys: keys, today: today, calendar: utc) == 1)
    }

    @Test func zeroWhenNothingRecent() {
        #expect(StreakCalculator.streak(completedDayKeys: ["2026-06-10"], today: today, calendar: utc) == 0)
    }
}
