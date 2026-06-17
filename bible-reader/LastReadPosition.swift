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
