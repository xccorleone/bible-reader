import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct ReadingPlanTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ReadingPlan.self, ReadingSession.self, configurations: config)
        return ModelContext(container)
    }

    @Test func currentCreatesThenReusesSingleRow() throws {
        let context = try makeContext()
        let a = ReadingPlan.current(in: context)
        a.dailyTargetMinutes = 30
        try context.save()
        let b = ReadingPlan.current(in: context)
        #expect(b.dailyTargetMinutes == 30)
        #expect(try context.fetch(FetchDescriptor<ReadingPlan>()).count == 1)
    }

    @Test func defaultsAreDisabledWithTwentyMinutes() throws {
        let context = try makeContext()
        let p = ReadingPlan.current(in: context)
        #expect(p.isEnabled == false)
        #expect(p.dailyTargetMinutes == 20)
        #expect(p.selectionToken == nil)
    }
}
