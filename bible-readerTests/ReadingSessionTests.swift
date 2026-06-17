import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct ReadingSessionTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ReadingPlan.self, ReadingSession.self, configurations: config)
        return ModelContext(container)
    }

    @Test func sessionIsFetchOrCreatePerDay() throws {
        let context = try makeContext()
        let d1 = ReadingSession.session(for: "2026-06-17", in: context)
        d1.accumulatedSeconds = 120
        try context.save()
        let again = ReadingSession.session(for: "2026-06-17", in: context)
        #expect(again.accumulatedSeconds == 120)
        let d2 = ReadingSession.session(for: "2026-06-18", in: context)
        #expect(d2.accumulatedSeconds == 0)
        #expect(try context.fetch(FetchDescriptor<ReadingSession>()).count == 2)
    }
}
