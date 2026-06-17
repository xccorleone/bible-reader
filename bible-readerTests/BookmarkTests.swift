import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct BookmarkTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Bookmark.self, configurations: config)
        return ModelContext(container)
    }

    @Test func toggleAddsThenRemoves() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Bookmark.toggle(in: ctx, ref: ref)
        #expect(Bookmark.versesForChapter(in: ctx, book: 1, chapter: 1) == [1])
        Bookmark.toggle(in: ctx, ref: ref)
        #expect(Bookmark.versesForChapter(in: ctx, book: 1, chapter: 1).isEmpty)
    }

    @Test func versesForChapterScopedToChapter() throws {
        let ctx = try makeContext()
        Bookmark.toggle(in: ctx, ref: Reference(book: 1, chapter: 1, verse: 2))
        Bookmark.toggle(in: ctx, ref: Reference(book: 1, chapter: 2, verse: 1))
        #expect(Bookmark.versesForChapter(in: ctx, book: 1, chapter: 1) == [2])
    }
}
