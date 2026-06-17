import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct LastReadPositionTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LastReadPosition.self, configurations: config)
        return ModelContext(container)
    }

    @Test func updateInsertsThenUpdatesKeepingSingleRow() throws {
        let context = try makeContext()

        LastReadPosition.update(in: context, book: 1, chapter: 1, translationID: "cuv")
        LastReadPosition.update(in: context, book: 43, chapter: 3, translationID: "cuv")

        let all = try context.fetch(FetchDescriptor<LastReadPosition>())
        #expect(all.count == 1)
        #expect(all.first?.book == 43)
        #expect(all.first?.chapter == 3)
        #expect(all.first?.translationID == "cuv")
    }
}
