# Bible DB build tools

`build_bible_db.py` turns a source JSON into `../bible-reader/bible.sqlite`
(tables `books`, `verses`, FTS5 `verses_fts`), bundled into the app.

## Source JSON shape
A JSON array of 66 books in canonical Genesis→Revelation order. Array position
is the book number; `chapters` is an array of chapters, each an array of verse
strings.

    [ { "abbrev": "gn", "chapters": [ ["v1 text", "v2 text", ...], ... ] }, ... ]

## Build
    python3 build_bible_db.py source_cuv.json ../bible-reader/bible.sqlite cuv

## Test
    python3 -m unittest test_build_bible_db -v

## Data provenance
- **Source:** getbible.net v2 API, translation `cus` — <https://api.getbible.net/v2/cus.json>
- **Translation:** 和合本 (Chinese Union Version, "Union Simplified"), **简体字 / simplified Chinese**.
- **License:** Public Domain. The getbible metadata lists
  `"distribution_license": "Public Domain"`; the CUV was first published in 1919
  and is in the public domain. Upstream OSIS source: <http://bible.fhl.net>.
- **Downloaded:** 2026-06-17.
- **Conversion:** `convert_source.py` transforms the getbible structure
  (`books[].chapters[].verses[].text`) into the array-of-books shape above,
  sorting by book/chapter/verse number, asserting 66 contiguous books with no
  chapter/verse gaps, and stripping the leading BOM and trailing whitespace from
  each verse. The full-width space (`　`) before 神 is authentic CUV
  typography and is preserved.
- **Result:** 66 books, 31,103 verses (Genesis 50 ch, Psalms 150 ch,
  John 21 ch, Revelation 22 ch).

To reproduce:

    curl -sL -o raw_download.json https://api.getbible.net/v2/cus.json
    python3 convert_source.py raw_download.json source_cuv.json
    python3 build_bible_db.py source_cuv.json ../bible-reader/bible.sqlite cuv

> **FTS note:** `verses_fts` uses the default FTS5 `unicode61` tokenizer, which
> does not segment runs of CJK characters. A bare single-character query like
> `神` only matches verses where that character stands alone as a
> whitespace-delimited token; use a prefix query (`神*`) for substring-style
> matching (e.g. `神*` matches ~3,600 verses; 神 appears literally in ~4,000).

Raw `source_*.json` / `raw_download.json` are gitignored; only the built
`bible.sqlite` and the converter are committed.
