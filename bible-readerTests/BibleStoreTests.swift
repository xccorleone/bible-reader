import Foundation
import Testing
@testable import bible_reader

private let SEED_SQL = """
CREATE TABLE books (id INTEGER PRIMARY KEY, name_zh TEXT, name_en TEXT,
    testament TEXT, chapter_count INTEGER, sort_order INTEGER);
CREATE TABLE verses (translation_id TEXT, book INTEGER, chapter INTEGER,
    verse INTEGER, text TEXT,
    PRIMARY KEY(translation_id, book, chapter, verse));
INSERT INTO books VALUES (1,'创世记','Genesis','OT',2,1);
INSERT INTO books VALUES (43,'约翰福音','John','NT',1,43);
INSERT INTO verses VALUES ('cuv',1,1,1,'起初神创造天地。');
INSERT INTO verses VALUES ('cuv',1,1,2,'地是空虚混沌。');
INSERT INTO verses VALUES ('cuv',1,2,1,'天地万物都造齐了。');
INSERT INTO verses VALUES ('cuv',43,1,1,'太初有道。');
"""

private func makeTestStore() throws -> BibleStore {
    try BibleStore.inMemory(seedSQL: SEED_SQL, translationID: "cuv")
}

struct BibleStoreTests {
    @Test func listsBooksInSortOrder() throws {
        let store = try makeTestStore()
        let books = try store.allBooks()
        #expect(books.map(\.id) == [1, 43])
        #expect(books[0].nameZH == "创世记")
        #expect(books[0].chapterCount == 2)
    }

    @Test func fetchesVersesForChapterInOrder() throws {
        let store = try makeTestStore()
        let verses = try store.verses(book: 1, chapter: 1)
        #expect(verses.map(\.number) == [1, 2])
        #expect(verses[0].text == "起初神创造天地。")
    }

    @Test func emptyChapterReturnsEmptyArray() throws {
        let store = try makeTestStore()
        let verses = try store.verses(book: 1, chapter: 99)
        #expect(verses.isEmpty)
    }

    // Integration: exercises the real bundled bible.sqlite via the app host.
    @Test func bundledDatabaseLoadsRealCUV() throws {
        let store = try BibleStore.bundled(translationID: "cuv")
        let books = try store.allBooks()
        #expect(books.count == 66)
        #expect(books.first?.id == 1)
        #expect(books.first { $0.id == 43 }?.chapterCount == 21)  // John has 21 chapters

        let genesis1 = try store.verses(book: 1, chapter: 1)
        #expect(genesis1.count >= 31)                              // Genesis 1 has 31 verses
        #expect(genesis1.first?.text.contains("起初") == true)
    }

    @Test func opensTranslationFromFilePath() throws {
        // Build a real on-disk DB with a second translation, then reopen read-only.
        let dir = URL.temporaryDirectory.appending(path: "store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appending(path: "kjv.sqlite").path

        let seed = try BibleStore.inMemory(seedSQL: """
            CREATE TABLE verses (translation_id TEXT, book INTEGER, chapter INTEGER,
                verse INTEGER, text TEXT,
                PRIMARY KEY(translation_id, book, chapter, verse));
            INSERT INTO verses VALUES ('kjv',1,1,1,'In the beginning God created the heaven and the earth.');
            """, translationID: "kjv")
        try seed.vacuum(into: path)

        let store = try BibleStore.file(at: path, translationID: "kjv")
        let verses = try store.verses(book: 1, chapter: 1)
        #expect(verses == [Verse(number: 1, text: "In the beginning God created the heaven and the earth.")])
    }
}
