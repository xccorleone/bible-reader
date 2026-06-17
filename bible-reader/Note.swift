import Foundation
import SwiftData

/// A free-text note on a single verse.
@Model
final class Note {
    var book: Int
    var chapter: Int
    var verse: Int
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(book: Int, chapter: Int, verse: Int, body: String,
         createdAt: Date = .now, updatedAt: Date = .now) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(ref: Reference, body: String) {
        self.init(book: ref.book, chapter: ref.chapter, verse: ref.verse, body: body)
    }

    var ref: Reference { Reference(book: book, chapter: chapter, verse: verse) }
}

extension Note {
    /// Creates/updates the note for `ref`. A blank body deletes the note.
    static func upsert(in context: ModelContext, ref: Reference, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = ref.book
        let c = ref.chapter
        let v = ref.verse
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        let existing = (try? context.fetch(descriptor))?.first
        if trimmed.isEmpty {
            if let existing { context.delete(existing) }
        } else if let existing {
            existing.body = trimmed
            existing.updatedAt = .now
        } else {
            context.insert(Note(ref: ref, body: trimmed))
        }
        try? context.save()
    }

    /// The note on `ref`, if any.
    static func fetch(in context: ModelContext, ref: Reference) -> Note? {
        let b = ref.book
        let c = ref.chapter
        let v = ref.verse
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.book == b && $0.chapter == c && $0.verse == v })
        return (try? context.fetch(descriptor))?.first
    }

    /// Map of verse number → Note for the given chapter.
    static func versesForChapter(in context: ModelContext, book: Int, chapter: Int) -> [Int: Note] {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.book == book && $0.chapter == chapter })
        let rows = (try? context.fetch(descriptor)) ?? []
        return Dictionary(rows.map { ($0.verse, $0) }, uniquingKeysWith: { _, new in new })
    }
}
