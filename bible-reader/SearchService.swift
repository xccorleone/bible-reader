import Foundation
import GRDB

/// A single full-text search hit: a verse reference plus the verse text used
/// as its snippet.
struct SearchResult: Identifiable, Hashable {
    let ref: Reference
    let snippet: String
    var id: Reference { ref }
}

/// Full-text search over the bundled Bible database (FTS5 trigram index).
///
/// Queries of 3+ characters use the trigram-accelerated `MATCH`; 1–2 character
/// queries produce no trigrams, so they fall back to a `LIKE` scan (cheap at
/// ~31k verses). See the project memory `fts-trigram-3char-minimum`.
struct SearchService {
    let dbQueue: DatabaseQueue
    let translationID: String

    init(store: BibleStore) {
        self.dbQueue = store.dbQueue
        self.translationID = store.translationID
    }

    func search(_ query: String, limit: Int = 200) throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return trimmed.count < 3
            ? try likeSearch(trimmed, limit: limit)
            : try ftsSearch(trimmed, limit: limit)
    }

    private func ftsSearch(_ term: String, limit: Int) throws -> [SearchResult] {
        // Wrap the term as a quoted FTS5 phrase so punctuation/spaces in user
        // input can't be parsed as query operators.
        let phrase = "\"" + term.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        return try dbQueue.read { db in
            try rows(db, sql: """
                SELECT book, chapter, verse, text FROM verses_fts
                WHERE translation_id = ? AND verses_fts MATCH ?
                ORDER BY book, chapter, verse
                LIMIT ?
            """, arguments: [translationID, phrase, limit])
        }
    }

    private func likeSearch(_ term: String, limit: Int) throws -> [SearchResult] {
        let escaped = term
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return try dbQueue.read { db in
            try rows(db, sql: """
                SELECT book, chapter, verse, text FROM verses
                WHERE translation_id = ? AND text LIKE ? ESCAPE '\\'
                ORDER BY book, chapter, verse
                LIMIT ?
            """, arguments: [translationID, "%\(escaped)%", limit])
        }
    }

    private func rows(_ db: Database, sql: String, arguments: StatementArguments) throws -> [SearchResult] {
        try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
            SearchResult(
                ref: Reference(book: row["book"], chapter: row["chapter"], verse: row["verse"]),
                snippet: row["text"]
            )
        }
    }
}
