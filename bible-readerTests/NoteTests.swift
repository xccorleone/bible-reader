import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct NoteTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, configurations: config)
        return ModelContext(container)
    }

    @Test func upsertCreatesThenUpdatesKeepingSingleRow() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Note.upsert(in: ctx, ref: ref, body: "first")
        Note.upsert(in: ctx, ref: ref, body: "second")
        let all = try ctx.fetch(FetchDescriptor<Note>())
        #expect(all.count == 1)
        #expect(Note.fetch(in: ctx, ref: ref)?.body == "second")
    }

    @Test func upsertEmptyBodyDeletes() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Note.upsert(in: ctx, ref: ref, body: "x")
        Note.upsert(in: ctx, ref: ref, body: "   ")
        #expect(Note.fetch(in: ctx, ref: ref) == nil)
    }
}
