# tools/test_build_bible_db.py
import json
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

    def test_book_number_follows_array_position(self):
        # The second book in the source array becomes book 2.
        row = self.conn.execute(
            "SELECT text FROM verses WHERE book=2 AND chapter=1 AND verse=1"
        ).fetchone()
        self.assertEqual(row[0], "以色列的众子，各带家眷，和雅各一同来到埃及。")

    def test_book_metadata_derived(self):
        row = self.conn.execute(
            "SELECT name_zh, name_en, testament, chapter_count FROM books WHERE id=1"
        ).fetchone()
        self.assertEqual(row, ("创世记", "Genesis", "OT", 2))  # fixture has 2 chapters in Genesis

    def test_only_present_books_in_metadata(self):
        ids = [r[0] for r in self.conn.execute("SELECT id FROM books ORDER BY id").fetchall()]
        self.assertEqual(ids, [1, 2])  # only the two fixture books have verses

    def test_fts_matches_chinese_phrase(self):
        # A multi-character Chinese phrase must match via FTS5. The default
        # unicode61 tokenizer does not segment CJK runs, so this requires the
        # trigram tokenizer.
        rows = self.conn.execute(
            "SELECT book, chapter, verse FROM verses_fts WHERE verses_fts MATCH ?",
            ("神创造",),
        ).fetchall()
        self.assertIn((1, 1, 1), rows)  # 起初神创造天地。


class OmittedVerseTests(unittest.TestCase):
    """Translations with textual-variant omissions (e.g. WEB Luke 17:36) reach
    build_bible_db as empty-string placeholders from convert_source gap-filling.
    The builder must skip them while keeping later verses at their true number."""

    def test_empty_verse_skipped_keeps_numbering(self):
        # Chapter with verse 2 omitted: ["v1", "", "v3"].
        src = [{"abbrev": "x", "chapters": [["v1", "", "v3"]]}]
        src_file = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
        json.dump(src, src_file)
        src_file.close()
        db_file = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
        db_file.close()
        try:
            build_bible_db.build(src_file.name, db_file.name, translation_id="web")
            conn = sqlite3.connect(db_file.name)
            try:
                rows = conn.execute("SELECT verse, text FROM verses ORDER BY verse").fetchall()
                self.assertEqual(rows, [(1, "v1"), (3, "v3")])  # no verse 2; v3 keeps its number
                fts_count = conn.execute("SELECT COUNT(*) FROM verses_fts").fetchone()[0]
                self.assertEqual(fts_count, 2)  # empty verse not indexed either
            finally:
                conn.close()
        finally:
            os.unlink(src_file.name)
            os.unlink(db_file.name)


if __name__ == "__main__":
    unittest.main()
