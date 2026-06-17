import Foundation
import SwiftData

/// A bookmark on a single verse. Flat columns keep it queryable by #Predicate.
@Model
final class Bookmark {
    var book: Int
    var chapter: Int
    var verse: Int
    var createdAt: Date

    init(book: Int, chapter: Int, verse: Int, createdAt: Date = .now) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.createdAt = createdAt
    }

    convenience init(ref: Reference, createdAt: Date = .now) {
        self.init(book: ref.book, chapter: ref.chapter, verse: ref.verse, createdAt: createdAt)
    }

    var ref: Reference { Reference(book: book, chapter: chapter, verse: verse) }
}

extension Bookmark {
    /// Adds a bookmark for `ref` if absent, removes it if present.
    static func toggle(in context: ModelContext, ref: Reference) {
        let b = ref.book
        let c = ref.chapter
        let v = ref.verse
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
        } else {
            context.insert(Bookmark(ref: ref))
        }
        try? context.save()
    }

    /// Verse numbers bookmarked in the given chapter.
    static func versesForChapter(in context: ModelContext, book: Int, chapter: Int) -> Set<Int> {
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.book == book && $0.chapter == chapter })
        let rows = (try? context.fetch(descriptor)) ?? []
        return Set(rows.map(\.verse))
    }
}
