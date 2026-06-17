import Testing
@testable import bible_reader

// Seed includes the FTS5 trigram virtual table so SearchService can exercise
// both the MATCH path (3+ chars) and the LIKE fallback (1–2 chars).
private let SEED_SQL = """
CREATE TABLE books (id INTEGER PRIMARY KEY, name_zh TEXT, name_en TEXT,
    testament TEXT, chapter_count INTEGER, sort_order INTEGER);
CREATE TABLE verses (translation_id TEXT, book INTEGER, chapter INTEGER,
    verse INTEGER, text TEXT,
    PRIMARY KEY(translation_id, book, chapter, verse));
CREATE VIRTUAL TABLE verses_fts USING fts5(
    text, translation_id UNINDEXED, book UNINDEXED, chapter UNINDEXED,
    verse UNINDEXED, tokenize='trigram');
INSERT INTO books VALUES (1,'创世记','Genesis','OT',2,1);
INSERT INTO books VALUES (43,'约翰福音','John','NT',1,43);
INSERT INTO verses VALUES ('cuv',1,1,1,'起初神创造天地。');
INSERT INTO verses VALUES ('cuv',1,1,2,'地是空虚混沌,渊面黑暗。');
INSERT INTO verses VALUES ('cuv',1,2,1,'天地万物都造齐了。');
INSERT INTO verses VALUES ('cuv',43,1,1,'太初有道,道与神同在,道就是神。');
INSERT INTO verses_fts (text, translation_id, book, chapter, verse)
    SELECT text, translation_id, book, chapter, verse FROM verses;
"""

private func makeService() throws -> SearchService {
    let store = try BibleStore.inMemory(seedSQL: SEED_SQL, translationID: "cuv")
    return SearchService(store: store)
}

struct SearchServiceTests {
    @Test func matchesMultiCharacterPhraseViaFTS() throws {
        let service = try makeService()
        let results = try service.search("神创造")
        #expect(results.map(\.ref) == [Reference(book: 1, chapter: 1, verse: 1)])
    }

    @Test func findsAllVersesContainingTerm() throws {
        let service = try makeService()
        let results = try service.search("天地")
        let refs = Set(results.map(\.ref))
        #expect(refs == [
            Reference(book: 1, chapter: 1, verse: 1),
            Reference(book: 1, chapter: 2, verse: 1),
        ])
    }

    @Test func shortQueryUsesLikeFallback() throws {
        // "道" is a single character — produces no trigrams, so MATCH would
        // return nothing; the LIKE fallback must still find it.
        let service = try makeService()
        let results = try service.search("道")
        #expect(results.map(\.ref) == [Reference(book: 43, chapter: 1, verse: 1)])
    }

    @Test func resultsCarrySnippetContainingQuery() throws {
        let service = try makeService()
        let result = try #require(try service.search("起初").first)
        #expect(result.snippet.contains("起初"))
    }

    @Test func emptyQueryReturnsNoResults() throws {
        let service = try makeService()
        #expect(try service.search("   ").isEmpty)
    }

    @Test func noMatchReturnsEmpty() throws {
        let service = try makeService()
        #expect(try service.search("耶路撒冷").isEmpty)
    }

    @Test func resultsAreOrderedByCanonicalPosition() throws {
        let service = try makeService()
        let results = try service.search("天地")
        #expect(results.map(\.ref) == [
            Reference(book: 1, chapter: 1, verse: 1),
            Reference(book: 1, chapter: 2, verse: 1),
        ])
    }
}
