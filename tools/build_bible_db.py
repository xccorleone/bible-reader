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
    verse UNINDEXED,
    tokenize='trigram'
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
                    # Skip omitted verses (empty placeholders from convert_source
                    # gap-filling): the DB carries no row, but verse_index keeps
                    # later verses at their true numbers (e.g. WEB Luke 17:37).
                    if text == "":
                        continue
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
