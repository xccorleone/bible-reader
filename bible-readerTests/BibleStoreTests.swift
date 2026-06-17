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
}
