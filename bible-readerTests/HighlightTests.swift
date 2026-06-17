import Testing
import SwiftData
@testable import bible_reader

@MainActor
struct HighlightTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Highlight.self, configurations: config)
        return ModelContext(container)
    }

    @Test func setColorThenChangeColorKeepsSingleRow() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Highlight.setColor(in: ctx, ref: ref, colorHex: "#FFE08A")
        Highlight.setColor(in: ctx, ref: ref, colorHex: "#A8D8F0")
        #expect(Highlight.versesForChapter(in: ctx, book: 1, chapter: 1) == [1: "#A8D8F0"])
    }

    @Test func removeDeletesHighlight() throws {
        let ctx = try makeContext()
        let ref = Reference(book: 1, chapter: 1, verse: 1)
        Highlight.setColor(in: ctx, ref: ref, colorHex: "#FFE08A")
        Highlight.remove(in: ctx, ref: ref)
        #expect(Highlight.versesForChapter(in: ctx, book: 1, chapter: 1).isEmpty)
    }
}
