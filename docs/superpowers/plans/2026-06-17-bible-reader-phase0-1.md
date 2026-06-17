# Bible Reader — Phase 0 + Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working offline iPhone Bible reader: a bundled SQLite Bible database (Phase 0) and a SwiftUI reading app with book → chapter → verse navigation, font/theme settings, and continue-reading (Phase 1).

**Architecture:** Bible text is stored in a read-only, bundled SQLite database with an FTS5 index, accessed through a thin `BibleStore` layer built on GRDB.swift. User data (last-read position) uses SwiftData. A one-off Python script (`tools/`) builds the database from a source JSON. The data-build script is tested with Python `unittest`; Swift code is tested with the Swift Testing framework in a new unit-test target.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData (Xcode 26.5, iOS 26.5), GRDB.swift (SwiftPM), Python 3.13 stdlib `sqlite3` (FTS5).

**Project facts (verified):**
- Xcode project: `bible-reader.xcodeproj`, single target & scheme `bible-reader`, bundle id `com.corleone.bible-reader`.
- Uses `PBXFileSystemSynchronizedRootGroup`: any file placed inside the `bible-reader/` folder is automatically compiled into the target (Swift) or bundled as a resource (e.g. `.sqlite`). **No manual "Add to target" needed for source/resource files.**
- Simulator for manual checks: `iPhone 17`.

---

## File Structure

**Phase 0 — data tooling (repo root, not in the app target):**
- `tools/build_bible_db.py` — builds `bible.sqlite` (books, verses, verses_fts) from a source JSON.
- `tools/books_meta.py` — static 66-book metadata (number → Chinese name, English name, testament).
- `tools/test_build_bible_db.py` — `unittest` tests against a small in-memory fixture.
- `tools/fixtures/sample_bible.json` — tiny fixture (a few verses) for tests.
- `tools/README.md` — how to obtain source data and run the build.
- `bible-reader/bible.sqlite` — the build output, bundled into the app (added in Phase 0, consumed in Phase 1).

**Phase 1 — app source (all under `bible-reader/`, auto-added to target):**
- `Reference.swift` — `Reference` value type `(book, chapter, verse)` + book-name lookup, shared across modules.
- `BibleStore.swift` — GRDB-backed read access: list books, list chapters, fetch verses.
- `Verse.swift` / `BookInfo.swift` — plain value types returned by `BibleStore`.
- `ReadingSettings.swift` — `@AppStorage`-backed font size & color scheme.
- `LastReadPosition.swift` — SwiftData `@Model` for continue-reading.
- `BookListView.swift`, `ChapterListView.swift`, `ReadingView.swift`, `SettingsView.swift` — screens.
- `ContentView.swift` — modified: root navigation, replaces the template's Item list.
- `bible_readerApp.swift` — modified: SwiftData schema becomes `[LastReadPosition]`.
- `Item.swift` — **deleted** (template placeholder).

**Phase 1 — tests (new unit-test target `bible-readerTests/`):**
- `BibleStoreTests.swift`, `ReferenceTests.swift`.

---

## Phase 0 — Bible Database

### Task 0.1: Book metadata module

**Files:**
- Create: `tools/books_meta.py`

- [ ] **Step 1: Create the metadata module**

```python
# tools/books_meta.py
"""Static metadata for the 66 Protestant-canon books.
Book numbers are stable across translations: 1=Genesis … 66=Revelation.
chapter_count is intentionally NOT stored here; it is derived from the
actual verse data at build time so it always matches the imported text.
"""

# (number, chinese_name, english_name)
BOOKS = [
    (1, "创世记", "Genesis"), (2, "出埃及记", "Exodus"), (3, "利未记", "Leviticus"),
    (4, "民数记", "Numbers"), (5, "申命记", "Deuteronomy"), (6, "约书亚记", "Joshua"),
    (7, "士师记", "Judges"), (8, "路得记", "Ruth"), (9, "撒母耳记上", "1 Samuel"),
    (10, "撒母耳记下", "2 Samuel"), (11, "列王纪上", "1 Kings"), (12, "列王纪下", "2 Kings"),
    (13, "历代志上", "1 Chronicles"), (14, "历代志下", "2 Chronicles"), (15, "以斯拉记", "Ezra"),
    (16, "尼希米记", "Nehemiah"), (17, "以斯帖记", "Esther"), (18, "约伯记", "Job"),
    (19, "诗篇", "Psalms"), (20, "箴言", "Proverbs"), (21, "传道书", "Ecclesiastes"),
    (22, "雅歌", "Song of Songs"), (23, "以赛亚书", "Isaiah"), (24, "耶利米书", "Jeremiah"),
    (25, "耶利米哀歌", "Lamentations"), (26, "以西结书", "Ezekiel"), (27, "但以理书", "Daniel"),
    (28, "何西阿书", "Hosea"), (29, "约珥书", "Joel"), (30, "阿摩司书", "Amos"),
    (31, "俄巴底亚书", "Obadiah"), (32, "约拿书", "Jonah"), (33, "弥迦书", "Micah"),
    (34, "那鸿书", "Nahum"), (35, "哈巴谷书", "Habakkuk"), (36, "西番雅书", "Zephaniah"),
    (37, "哈该书", "Haggai"), (38, "撒迦利亚书", "Zechariah"), (39, "玛拉基书", "Malachi"),
    (40, "马太福音", "Matthew"), (41, "马可福音", "Mark"), (42, "路加福音", "Luke"),
    (43, "约翰福音", "John"), (44, "使徒行传", "Acts"), (45, "罗马书", "Romans"),
    (46, "哥林多前书", "1 Corinthians"), (47, "哥林多后书", "2 Corinthians"),
    (48, "加拉太书", "Galatians"), (49, "以弗所书", "Ephesians"), (50, "腓立比书", "Philippians"),
    (51, "歌罗西书", "Colossians"), (52, "帖撒罗尼迦前书", "1 Thessalonians"),
    (53, "帖撒罗尼迦后书", "2 Thessalonians"), (54, "提摩太前书", "1 Timothy"),
    (55, "提摩太后书", "2 Timothy"), (56, "提多书", "Titus"), (57, "腓利门书", "Philemon"),
    (58, "希伯来书", "Hebrews"), (59, "雅各书", "James"), (60, "彼得前书", "1 Peter"),
    (61, "彼得后书", "2 Peter"), (62, "约翰一书", "1 John"), (63, "约翰二书", "2 John"),
    (64, "约翰三书", "3 John"), (65, "犹大书", "Jude"), (66, "启示录", "Revelation"),
]

def testament(book_number: int) -> str:
    """Books 1–39 are Old Testament, 40–66 New Testament."""
    return "OT" if book_number <= 39 else "NT"
```

- [ ] **Step 2: Sanity-check it loads**

Run: `cd tools && python3 -c "import books_meta; print(len(books_meta.BOOKS), books_meta.testament(40))"`
Expected output: `66 NT`

- [ ] **Step 3: Commit**

```bash
git add tools/books_meta.py
git commit -m "Add book metadata module for Bible DB build"
```

---

### Task 0.2: Test fixture

**Files:**
- Create: `tools/fixtures/sample_bible.json`

- [ ] **Step 1: Create the fixture**

The build script consumes a JSON array of 66 books, each `{"abbrev": str, "chapters": [[verse, ...], ...]}`, ordered Genesis→Revelation (this matches the widely-mirrored `thiagobodruk/bible` JSON shape). The fixture only fills two books so tests stay fast; missing books are allowed by the script (it imports whatever chapters are present).

```json
[
  { "abbrev": "gn", "chapters": [
      ["起初神创造天地。", "地是空虚混沌，渊面黑暗；神的灵运行在水面上。", "神说：要有光，就有了光。"],
      ["天地万物都造齐了。"]
  ]},
  { "abbrev": "jn", "chapters": [
      ["太初有道，道与神同在，道就是神。", "这道太初与神同在。"]
  ]}
]
```

- [ ] **Step 2: Commit**

```bash
git add tools/fixtures/sample_bible.json
git commit -m "Add sample Bible fixture for build-script tests"
```

---

### Task 0.3: Build script — schema & verse import (TDD)

**Files:**
- Create: `tools/build_bible_db.py`
- Test: `tools/test_build_bible_db.py`

- [ ] **Step 1: Write the failing test**

```python
# tools/test_build_bible_db.py
import os
import sqlite3
import tempfile
import unittest

import build_bible_db


FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "sample_bible.json")


class BuildBibleDBTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        self.tmp.close()
        self.db_path = self.tmp.name
        build_bible_db.build(FIXTURE, self.db_path, translation_id="cuv")
        self.conn = sqlite3.connect(self.db_path)

    def tearDown(self):
        self.conn.close()
        os.unlink(self.db_path)

    def test_verse_count(self):
        n = self.conn.execute("SELECT COUNT(*) FROM verses").fetchone()[0]
        self.assertEqual(n, 6)  # 3 + 1 + 2 verses in the fixture

    def test_fetch_specific_verse(self):
        row = self.conn.execute(
            "SELECT text FROM verses WHERE translation_id=? AND book=? AND chapter=? AND verse=?",
            ("cuv", 1, 1, 1),
        ).fetchone()
        self.assertEqual(row[0], "起初神创造天地。")

    def test_john_is_book_43(self):
        row = self.conn.execute(
            "SELECT text FROM verses WHERE book=43 AND chapter=1 AND verse=1"
        ).fetchone()
        self.assertEqual(row[0], "太初有道，道与神同在，道就是神。")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd tools && python3 -m unittest test_build_bible_db -v`
Expected: FAIL / ERROR — `ModuleNotFoundError: No module named 'build_bible_db'` (or `AttributeError: build`).

- [ ] **Step 3: Write the build script (schema + verse import)**

```python
# tools/build_bible_db.py
"""Build bible.sqlite from a source JSON.

Source JSON shape (array, Genesis→Revelation order):
  [ { "abbrev": "gn", "chapters": [ ["v1", "v2", ...], ... ] }, ... ]

Each book's position in the array is its book number (1-based). We do not
rely on `abbrev` for numbering — array order is authoritative.
"""
import json
import sqlite3
import sys

import books_meta

SCHEMA = """
CREATE TABLE books (
    id INTEGER PRIMARY KEY,
    name_zh TEXT NOT NULL,
    name_en TEXT NOT NULL,
    testament TEXT NOT NULL,
    chapter_count INTEGER NOT NULL,
    sort_order INTEGER NOT NULL
);
CREATE TABLE verses (
    translation_id TEXT NOT NULL,
    book INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    text TEXT NOT NULL,
    PRIMARY KEY (translation_id, book, chapter, verse)
);
CREATE VIRTUAL TABLE verses_fts USING fts5(
    text,
    translation_id UNINDEXED,
    book UNINDEXED,
    chapter UNINDEXED,
    verse UNINDEXED
);
"""


def build(source_json_path: str, db_path: str, translation_id: str) -> None:
    with open(source_json_path, encoding="utf-8") as f:
        data = json.load(f)

    conn = sqlite3.connect(db_path)
    try:
        # FTS5 must be available in this sqlite build.
        conn.executescript(SCHEMA)

        max_chapter_per_book = {}
        for book_index, book in enumerate(data, start=1):
            chapters = book.get("chapters", [])
            for chapter_index, verses in enumerate(chapters, start=1):
                for verse_index, text in enumerate(verses, start=1):
                    conn.execute(
                        "INSERT INTO verses (translation_id, book, chapter, verse, text) "
                        "VALUES (?, ?, ?, ?, ?)",
                        (translation_id, book_index, chapter_index, verse_index, text),
                    )
                    conn.execute(
                        "INSERT INTO verses_fts (text, translation_id, book, chapter, verse) "
                        "VALUES (?, ?, ?, ?, ?)",
                        (text, translation_id, book_index, chapter_index, verse_index),
                    )
                if chapters:
                    max_chapter_per_book[book_index] = len(chapters)

        # Book metadata: only for books that actually have verses.
        for number, name_zh, name_en in books_meta.BOOKS:
            chapter_count = max_chapter_per_book.get(number)
            if chapter_count is None:
                continue
            conn.execute(
                "INSERT INTO books (id, name_zh, name_en, testament, chapter_count, sort_order) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (number, name_zh, name_en, books_meta.testament(number), chapter_count, number),
            )
        conn.commit()
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 build_bible_db.py <source.json> <out.sqlite> <translation_id>")
        sys.exit(1)
    build(sys.argv[1], sys.argv[2], sys.argv[3])
    print(f"Built {sys.argv[2]} from {sys.argv[1]} (translation={sys.argv[3]})")
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd tools && python3 -m unittest test_build_bible_db -v`
Expected: PASS — 3 tests OK.

(If `test_verse_count`/FTS errors with "no such module: fts5", the local Python's sqlite3 lacks FTS5; STOP and resolve via systematic-debugging — e.g. use a python.org or Homebrew Python build. Do not proceed.)

- [ ] **Step 5: Commit**

```bash
git add tools/build_bible_db.py tools/test_build_bible_db.py
git commit -m "Add Bible DB build script with verse import and FTS5"
```

---

### Task 0.4: Build script — books metadata test (TDD)

**Files:**
- Modify: `tools/test_build_bible_db.py`

- [ ] **Step 1: Add the failing test**

Append this method inside the `BuildBibleDBTests` class:

```python
    def test_book_metadata_derived(self):
        row = self.conn.execute(
            "SELECT name_zh, name_en, testament, chapter_count FROM books WHERE id=1"
        ).fetchone()
        self.assertEqual(row, ("创世记", "Genesis", "OT", 2))  # fixture has 2 chapters in Genesis

    def test_only_present_books_in_metadata(self):
        ids = [r[0] for r in self.conn.execute("SELECT id FROM books ORDER BY id").fetchall()]
        self.assertEqual(ids, [1, 43])  # only Genesis & John have verses in the fixture
```

- [ ] **Step 2: Run the tests**

Run: `cd tools && python3 -m unittest test_build_bible_db -v`
Expected: PASS — 5 tests OK. (The build script from Task 0.3 already derives `chapter_count` and skips empty books, so these pass without code changes — this task locks that behavior in a regression test.)

- [ ] **Step 3: Commit**

```bash
git add tools/test_build_bible_db.py
git commit -m "Test derived book metadata in Bible DB build"
```

---

### Task 0.5: Acquire real data and build the bundled database

This is the one step requiring external data. The build tooling is already tested; here we feed it real text.

**Files:**
- Create: `tools/README.md`
- Create (build output, committed): `bible-reader/bible.sqlite`

- [ ] **Step 1: Obtain a public-domain Chinese Union Version (CUV) source**

The 和合本 (Union Version, 1919) is public domain. Obtain a JSON in the shape Task 0.2 documents (array of books, `chapters` = array of arrays of verse strings, Genesis→Revelation order). Candidate sources to evaluate (verify the license and the JSON shape before use; convert if the shape differs):
- `thiagobodruk/bible` (GitHub) — known clean `{abbrev, chapters}` shape; confirm whether a Chinese file is present.
- `getbible.net` v2 API / data dumps.
- Any other CUV dataset you trust; write a small converter into the documented shape if needed.

Save the converted source as `tools/source_cuv.json` (this file may be large; do NOT commit it — add `tools/source_*.json` to `.gitignore`).

- [ ] **Step 2: Add gitignore entry for raw sources**

Append to `.gitignore` (create the file if absent):

```
tools/source_*.json
```

- [ ] **Step 3: Build the database**

Run: `cd tools && python3 build_bible_db.py source_cuv.json ../bible-reader/bible.sqlite cuv`
Expected output: `Built ../bible-reader/bible.sqlite from source_cuv.json (translation=cuv)`

- [ ] **Step 4: Verify the built database**

Run:
```bash
sqlite3 bible-reader/bible.sqlite "SELECT COUNT(*) FROM verses; SELECT COUNT(*) FROM books; SELECT text FROM verses WHERE book=1 AND chapter=1 AND verse=1; SELECT count(*) FROM verses_fts WHERE verses_fts MATCH '神';"
```
Expected: verse count ~31,000; book count up to 66; Genesis 1:1 text printed; a non-zero FTS match count.

- [ ] **Step 5: Write tools/README.md**

```markdown
# Bible DB build tools

`build_bible_db.py` turns a source JSON into `../bible-reader/bible.sqlite`
(tables `books`, `verses`, FTS5 `verses_fts`), bundled into the app.

## Source JSON shape
Array of 66 books in Genesis→Revelation order. Array position = book number.

    [ { "abbrev": "gn", "chapters": [ ["v1 text", "v2 text", ...], ... ] }, ... ]

## Build
    python3 build_bible_db.py source_cuv.json ../bible-reader/bible.sqlite cuv

## Test
    python3 -m unittest test_build_bible_db -v

Raw `source_*.json` files are gitignored; only the built `bible.sqlite` is committed.
```

- [ ] **Step 6: Commit**

```bash
git add .gitignore tools/README.md bible-reader/bible.sqlite
git commit -m "Build and bundle CUV bible.sqlite"
```

> The `bible-reader/` folder is a filesystem-synchronized group, so `bible.sqlite` is automatically included as a bundled resource — no Xcode changes needed.

---

## Phase 1 — Reading App

### Task 1.1: Add GRDB dependency and a unit-test target (Xcode GUI)

These two setup steps require the Xcode UI (SwiftPM dependency resolution and target creation are not scripted here).

**Files:**
- Modify: `bible-reader.xcodeproj` (via Xcode GUI)

- [ ] **Step 1: Add GRDB.swift via Swift Package Manager**

In Xcode: **File ▸ Add Package Dependencies…** → enter `https://github.com/groue/GRDB.swift` → Dependency Rule: *Up to Next Major* from `7.0.0` → Add Package → add the **GRDB** library product to the **bible-reader** target.

- [ ] **Step 2: Add a unit-test target**

In Xcode: **File ▸ New ▸ Target… ▸ Unit Testing Bundle** (Testing System: **Swift Testing**) → name `bible-readerTests` → Target to be Tested: `bible-reader`. This creates the `bible-readerTests/` folder and a test scheme.

- [ ] **Step 3: Verify the project still builds**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Add GRDB dependency and unit-test target"
```

---

### Task 1.2: Reference value type (TDD)

**Files:**
- Create: `bible-reader/Reference.swift`
- Test: `bible-readerTests/ReferenceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// bible-readerTests/ReferenceTests.swift
import Testing
@testable import bible_reader

struct ReferenceTests {
    @Test func referenceIsEquatableByComponents() {
        let a = Reference(book: 1, chapter: 1, verse: 1)
        let b = Reference(book: 1, chapter: 1, verse: 1)
        #expect(a == b)
    }

    @Test func displayStringUsesChineseBookName() {
        let ref = Reference(book: 43, chapter: 3, verse: 16)
        #expect(ref.displayString(bookName: "约翰福音") == "约翰福音 3:16")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: build/compile failure — `cannot find 'Reference' in scope`.

- [ ] **Step 3: Implement the type**

```swift
// bible-reader/Reference.swift
import Foundation

/// A canonical pointer to a single verse. Book numbers are stable across
/// translations (1 = Genesis … 66 = Revelation).
struct Reference: Equatable, Hashable, Codable {
    var book: Int
    var chapter: Int
    var verse: Int

    func displayString(bookName: String) -> String {
        "\(bookName) \(chapter):\(verse)"
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: tests pass (`Test run ... passed`).

- [ ] **Step 5: Commit**

```bash
git add bible-reader/Reference.swift bible-readerTests/ReferenceTests.swift
git commit -m "Add Reference value type"
```

---

### Task 1.3: BibleStore — value types and book listing (TDD)

**Files:**
- Create: `bible-reader/BookInfo.swift`
- Create: `bible-reader/Verse.swift`
- Create: `bible-reader/BibleStore.swift`
- Test: `bible-readerTests/BibleStoreTests.swift`

- [ ] **Step 1: Write the failing test**

The test builds a tiny throwaway SQLite with the production schema so it never depends on the multi-MB bundled DB.

```swift
// bible-readerTests/BibleStoreTests.swift
import Testing
import GRDB
@testable import bible_reader

private func makeTestStore() throws -> BibleStore {
    let queue = try DatabaseQueue()  // in-memory
    try queue.write { db in
        try db.execute(sql: """
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
        """)
    }
    return BibleStore(dbQueue: queue, translationID: "cuv")
}

struct BibleStoreTests {
    @Test func listsBooksInSortOrder() throws {
        let store = try makeTestStore()
        let books = try store.allBooks()
        #expect(books.map(\.id) == [1, 43])
        #expect(books[0].nameZH == "创世记")
        #expect(books[0].chapterCount == 2)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: compile failure — `cannot find 'BibleStore'` / `'BookInfo'`.

- [ ] **Step 3: Implement value types**

```swift
// bible-reader/BookInfo.swift
struct BookInfo: Identifiable, Hashable {
    let id: Int          // book number 1…66
    let nameZH: String
    let nameEN: String
    let testament: String
    let chapterCount: Int
}
```

```swift
// bible-reader/Verse.swift
struct Verse: Identifiable, Hashable {
    let number: Int      // verse number within the chapter
    let text: String
    var id: Int { number }
}
```

- [ ] **Step 4: Implement BibleStore with book listing**

```swift
// bible-reader/BibleStore.swift
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
}

enum BibleStoreError: Error { case databaseMissing }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add bible-reader/BookInfo.swift bible-reader/Verse.swift bible-reader/BibleStore.swift bible-readerTests/BibleStoreTests.swift
git commit -m "Add BibleStore with book listing"
```

---

### Task 1.4: BibleStore — fetch verses for a chapter (TDD)

**Files:**
- Modify: `bible-reader/BibleStore.swift`
- Test: `bible-readerTests/BibleStoreTests.swift`

- [ ] **Step 1: Add the failing test**

Add inside `struct BibleStoreTests`:

```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: compile failure — `value of type 'BibleStore' has no member 'verses'`.

- [ ] **Step 3: Implement the method**

Add this method inside `struct BibleStore`:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add bible-reader/BibleStore.swift bible-readerTests/BibleStoreTests.swift
git commit -m "Add verse fetch to BibleStore"
```

---

### Task 1.5: Reading settings (font size & color scheme)

No new logic to unit-test (thin `@AppStorage` wrapper); verified by use in later screens.

**Files:**
- Create: `bible-reader/ReadingSettings.swift`

- [ ] **Step 1: Implement settings store**

```swift
// bible-reader/ReadingSettings.swift
import SwiftUI

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Observable reading preferences, persisted via UserDefaults.
@Observable
final class ReadingSettings {
    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    var colorScheme: AppColorScheme {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme") }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: "fontSize")
        self.fontSize = stored == 0 ? 18 : stored
        let raw = UserDefaults.standard.string(forKey: "colorScheme") ?? AppColorScheme.system.rawValue
        self.colorScheme = AppColorScheme(rawValue: raw) ?? .system
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/ReadingSettings.swift
git commit -m "Add reading settings (font size, color scheme)"
```

---

### Task 1.6: LastReadPosition SwiftData model

**Files:**
- Create: `bible-reader/LastReadPosition.swift`

- [ ] **Step 1: Implement the model**

```swift
// bible-reader/LastReadPosition.swift
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
```

- [ ] **Step 2: Verify it compiles**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add bible-reader/LastReadPosition.swift
git commit -m "Add LastReadPosition SwiftData model"
```

---

### Task 1.7: Wire app entry point — swap schema, delete placeholder

**Files:**
- Modify: `bible-reader/bible_readerApp.swift`
- Delete: `bible-reader/Item.swift`

- [ ] **Step 1: Update the app entry to inject BibleStore and the new schema**

```swift
// bible-reader/bible_readerApp.swift
import SwiftUI
import SwiftData

@main
struct bible_readerApp: App {
    @State private var settings = ReadingSettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([LastReadPosition.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .preferredColorScheme(settings.colorScheme.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- [ ] **Step 2: Delete the template placeholder**

Run: `git rm bible-reader/Item.swift`

- [ ] **Step 3: Verify (will fail to build until ContentView is updated)**

Note: `ContentView` still references `Item` at this point; it is rewritten in Task 1.8. Do not build between these two tasks — proceed directly to Task 1.8, then build there.

- [ ] **Step 4: Stage the changes (commit together with Task 1.8)**

Leave changes staged; they are committed at the end of Task 1.8 so the tree never contains a non-building commit.

```bash
git add bible-reader/bible_readerApp.swift
```

---

### Task 1.8: Book list + chapter list + reading screens

**Files:**
- Create: `bible-reader/BookListView.swift`
- Create: `bible-reader/ChapterListView.swift`
- Create: `bible-reader/ReadingView.swift`
- Create: `bible-reader/SettingsView.swift`
- Modify: `bible-reader/ContentView.swift`

- [ ] **Step 1: Implement the reading view**

```swift
// bible-reader/ReadingView.swift
import SwiftUI
import SwiftData

struct ReadingView: View {
    let store: BibleStore
    let book: BookInfo
    let chapter: Int

    @Environment(ReadingSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var verses: [Verse] = []
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(verses) { verse in
                    (Text("\(verse.number) ").font(.system(size: settings.fontSize * 0.7))
                        .foregroundStyle(.secondary)
                     + Text(verse.text).font(.system(size: settings.fontSize)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("\(book.nameZH) \(chapter)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: chapter) { load() }
    }

    private func load() {
        do {
            verses = try store.verses(book: book.id, chapter: chapter)
            savePosition()
        } catch {
            loadError = "无法加载经文：\(error.localizedDescription)"
        }
    }

    private func savePosition() {
        let descriptor = FetchDescriptor<LastReadPosition>()
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.book = book.id
            existing.chapter = chapter
            existing.translationID = store.translationID
            existing.updatedAt = .now
        } else {
            modelContext.insert(LastReadPosition(
                book: book.id, chapter: chapter, translationID: store.translationID))
        }
    }
}
```

- [ ] **Step 2: Implement the chapter list**

```swift
// bible-reader/ChapterListView.swift
import SwiftUI

struct ChapterListView: View {
    let store: BibleStore
    let book: BookInfo

    private let columns = [GridItem(.adaptive(minimum: 56))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...book.chapterCount, id: \.self) { chapter in
                    NavigationLink(value: NavRoute.reading(book: book, chapter: chapter)) {
                        Text("\(chapter)")
                            .frame(width: 56, height: 56)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(book.nameZH)
    }
}
```

- [ ] **Step 3: Implement the book list**

```swift
// bible-reader/BookListView.swift
import SwiftUI

struct BookListView: View {
    let store: BibleStore
    @State private var books: [BookInfo] = []
    @State private var loadError: String?

    var body: some View {
        List {
            if let loadError {
                Text(loadError).foregroundStyle(.red)
            }
            Section("旧约") {
                ForEach(books.filter { $0.testament == "OT" }) { book in
                    NavigationLink(book.nameZH, value: NavRoute.chapters(book: book))
                }
            }
            Section("新约") {
                ForEach(books.filter { $0.testament == "NT" }) { book in
                    NavigationLink(book.nameZH, value: NavRoute.chapters(book: book))
                }
            }
        }
        .navigationTitle("圣经")
        .task { load() }
    }

    private func load() {
        do { books = try store.allBooks() }
        catch { loadError = "无法加载书卷：\(error.localizedDescription)" }
    }
}
```

- [ ] **Step 4: Implement settings screen**

```swift
// bible-reader/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("字体大小") {
                Slider(value: $settings.fontSize, in: 12...32, step: 1)
                Text("示例经文 \(Int(settings.fontSize))pt")
                    .font(.system(size: settings.fontSize))
            }
            Section("外观") {
                Picker("主题", selection: $settings.colorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
            }
        }
        .navigationTitle("设置")
    }
}
```

- [ ] **Step 5: Rewrite ContentView with navigation and continue-reading**

```swift
// bible-reader/ContentView.swift
import SwiftUI
import SwiftData

/// Navigation destinations pushed onto the reading stack.
enum NavRoute: Hashable {
    case chapters(book: BookInfo)
    case reading(book: BookInfo, chapter: Int)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var positions: [LastReadPosition]

    @State private var store: BibleStore?
    @State private var fatalMessage: String?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let store {
                    BookListView(store: store)
                        .navigationDestination(for: NavRoute.self) { route in
                            switch route {
                            case let .chapters(book):
                                ChapterListView(store: store, book: book)
                            case let .reading(book, chapter):
                                ReadingView(store: store, book: book, chapter: chapter)
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink { SettingsView() } label: {
                                    Image(systemName: "textformat.size")
                                }
                            }
                            if let last = positions.first,
                               let book = try? store.allBooks().first(where: { $0.id == last.book }) {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("续读") {
                                        path.append(NavRoute.reading(book: book, chapter: last.chapter))
                                    }
                                }
                            }
                        }
                } else if let fatalMessage {
                    ContentUnavailableView("无法打开圣经数据", systemImage: "exclamationmark.triangle", description: Text(fatalMessage))
                } else {
                    ProgressView()
                }
            }
        }
        .task { openStore() }
    }

    private func openStore() {
        guard store == nil else { return }
        do { store = try BibleStore.bundled(translationID: "cuv") }
        catch { fatalMessage = "请确认 bible.sqlite 已打包。(\(error))" }
    }
}
```

- [ ] **Step 6: Build and verify**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run the full test suite**

Run:
```bash
xcodebuild -project bible-reader.xcodeproj -scheme bible-reader -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -15
```
Expected: all tests pass.

- [ ] **Step 8: Manual smoke test on the simulator**

Launch the app (Xcode ▸ Run, or boot `iPhone 17`). Verify: book list shows 旧约/新约 sections → tap 创世记 → chapter grid → tap 1 → verses render with verse numbers. Change font size in 设置 and confirm verses resize. Toggle 深色 theme. Re-launch and confirm 续读 jumps to the last chapter.

- [ ] **Step 9: Commit (includes Task 1.7 staged changes)**

```bash
git add -A
git commit -m "Add reading UI: book list, chapter grid, reading view, settings, continue-reading"
```

---

## Self-Review Notes (coverage against spec)

- Spec §3 (SQLite schema books/verses/verses_fts) → Task 0.3. FTS5 built now; consumed by search in Phase 3 (out of scope here).
- Spec §3 user data `LastReadPosition` → Task 1.6, used in Task 1.8. Other SwiftData models (Bookmark/Highlight/Note/ReadingPlan/ReadingSession) are Phases 2–5, intentionally out of scope.
- Spec §2 module boundaries `BibleStore` → Tasks 1.3–1.4; `ReferenceModel` → Task 1.2. `SearchService`/`LockController`/`ReadingTimer` are later phases.
- Spec §4 Phase 0 (build bible.sqlite, FTS5, books metadata) → Tasks 0.1–0.5. Phase 1 (navigation, reading, font/theme, continue-reading, delete Item.swift) → Tasks 1.1–1.8.
- Spec §6 error handling: missing DB → `BibleStoreError.databaseMissing` surfaced via `ContentUnavailableView` (Task 1.8); load errors surfaced inline (Tasks 1.8).
- Spec §7 testing: Python unittest for the build script (Tasks 0.3–0.4); Swift Testing for `Reference` and `BibleStore` against an in-memory fixture DB (Tasks 1.2–1.4).

**Known manual/external dependency:** Task 0.5 (acquire CUV source) and Task 1.1 (Xcode GUI: add GRDB + test target) cannot be fully scripted; both have explicit verification steps.
