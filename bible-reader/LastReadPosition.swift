import Foundation
import SwiftData

/// Persists the most recent reading location for continue-reading.
/// A single row is kept (created on first read, updated thereafter).
@Model
final class LastReadPosition {
    var book: Int
    var chapter: Int
    var translationID: String
    var updatedAt: Date

    init(book: Int, chapter: Int, translationID: String, updatedAt: Date = .now) {
        self.book = book
        self.chapter = chapter
        self.translationID = translationID
        self.updatedAt = updatedAt
    }
}

extension LastReadPosition {
    /// Upserts the single last-read row in `context` and persists it.
    @discardableResult
    static func update(in context: ModelContext, book: Int, chapter: Int, translationID: String) -> LastReadPosition {
        let descriptor = FetchDescriptor<LastReadPosition>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let position: LastReadPosition
        if let existing = try? context.fetch(descriptor).first {
            existing.book = book
            existing.chapter = chapter
            existing.translationID = translationID
            existing.updatedAt = .now
            position = existing
        } else {
            position = LastReadPosition(book: book, chapter: chapter, translationID: translationID)
            context.insert(position)
        }
        try? context.save()
        return position
    }
}
