import Foundation
import SwiftData

/// A whole-verse highlight. One row per verse (not a start/end range), so
/// rendering and recolor/remove are direct single-verse operations.
@Model
final class Highlight {
    var book: Int
    var chapter: Int
    var verse: Int
    var colorHex: String
    var createdAt: Date

    init(book: Int, chapter: Int, verse: Int, colorHex: String, createdAt: Date = .now) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    convenience init(ref: Reference, colorHex: String, createdAt: Date = .now) {
        self.init(book: ref.book, chapter: ref.chapter, verse: ref.verse,
                  colorHex: colorHex, createdAt: createdAt)
    }

    var ref: Reference { Reference(book: book, chapter: chapter, verse: verse) }
}

extension Highlight {
    /// Upserts the highlight for `ref`, setting its color.
    static func setColor(in context: ModelContext, ref: Reference, colorHex: String) {
        let b = ref.book
        let c = ref.chapter
        let v = ref.verse
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.colorHex = colorHex
        } else {
            context.insert(Highlight(ref: ref, colorHex: colorHex))
        }
        try? context.save()
    }

    /// Removes the highlight on `ref`, if any.
    static func remove(in context: ModelContext, ref: Reference) {
        let b = ref.book
        let c = ref.chapter
        let v = ref.verse
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
            try? context.save()
        }
    }

    /// Map of verse number → color hex for the given chapter.
    static func versesForChapter(in context: ModelContext, book: Int, chapter: Int) -> [Int: String] {
        let descriptor = FetchDescriptor<Highlight>(
            predicate: #Predicate { $0.book == book && $0.chapter == chapter })
        let rows = (try? context.fetch(descriptor)) ?? []
        return Dictionary(rows.map { ($0.verse, $0.colorHex) }, uniquingKeysWith: { _, new in new })
    }
}
