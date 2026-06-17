import Foundation
import GRDB

/// Read-only access to the bundled Bible database.
struct BibleStore {
    let dbQueue: DatabaseQueue
    let translationID: String

    /// Opens the read-only database bundled in the app.
    static func bundled(translationID: String = "cuv") throws -> BibleStore {
        guard let url = Bundle.main.url(forResource: "bible", withExtension: "sqlite") else {
            throw BibleStoreError.databaseMissing
        }
        var config = Configuration()
        config.readonly = true
        let queue = try DatabaseQueue(path: url.path, configuration: config)
        return BibleStore(dbQueue: queue, translationID: translationID)
    }

    /// Opens a downloaded translation database read-only from an absolute path.
    static func file(at path: String, translationID: String) throws -> BibleStore {
        var config = Configuration()
        config.readonly = true
        let queue = try DatabaseQueue(path: path, configuration: config)
        return BibleStore(dbQueue: queue, translationID: translationID)
    }

    func allBooks() throws -> [BookInfo] {
        try dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, name_zh, name_en, testament, chapter_count
                FROM books ORDER BY sort_order
            """).map { row in
                BookInfo(
                    id: row["id"], nameZH: row["name_zh"], nameEN: row["name_en"],
                    testament: row["testament"], chapterCount: row["chapter_count"]
                )
            }
        }
    }

    func verses(book: Int, chapter: Int) throws -> [Verse] {
        try dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT verse, text FROM verses
                WHERE translation_id = ? AND book = ? AND chapter = ?
                ORDER BY verse
            """, arguments: [translationID, book, chapter]).map { row in
                Verse(number: row["verse"], text: row["text"])
            }
        }
    }
}

enum BibleStoreError: Error { case databaseMissing }

#if DEBUG
extension BibleStore {
    /// Builds an in-memory store seeded with raw SQL. Test-only seam so the
    /// unit-test target can exercise `BibleStore` without linking GRDB itself.
    static func inMemory(seedSQL: String, translationID: String) throws -> BibleStore {
        let queue = try DatabaseQueue()
        try queue.write { db in try db.execute(sql: seedSQL) }
        return BibleStore(dbQueue: queue, translationID: translationID)
    }

    /// Writes the in-memory database to a file path using `VACUUM INTO`.
    /// Test-only helper so callers don't need to import GRDB directly.
    func vacuum(into path: String) throws {
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM INTO ?", arguments: [path])
        }
    }
}
#endif
