# Bible DB build tools

`build_bible_db.py` turns a source JSON into `../bible-reader/bible.sqlite`
(tables `books`, `verses`, FTS5 `verses_fts`), bundled into the app.

## Source JSON shape
A JSON array of 66 books in canonical Genesis→Revelation order. Array position
is the book number; `chapters` is an array of chapters, each an array of verse
strings.

    [ { "abbrev": "gn", "chapters": [ ["v1 text", "v2 text", ...], ... ] }, ... ]

## Build
    python3 build_bible_db.py source_cuv.json ../bible-reader/bible.sqlite cuv paragraphs_cuv.json

The optional 4th argument is a paragraph map (see **Paragraphs (分段)** below); the
builder writes a `verses.para_start` flag (1 = this verse begins a paragraph).
Omit it to build a translation with no paragraph data (`para_start` stays 0).

> The builder requires a **fresh** output path — delete an existing
> `bible.sqlite` first (`rm -f ../bible-reader/bible.sqlite`), it does not
> overwrite tables in place.

## Test
    python3 -m unittest test_build_bible_db test_extract_paragraphs -v

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
    rm -f ../bible-reader/bible.sqlite
    python3 build_bible_db.py source_cuv.json ../bible-reader/bible.sqlite cuv paragraphs_cuv.json

## Paragraphs (分段)

The getbible `cus` text is flat — no paragraph or section structure. Paragraph
breaks are sourced separately from the USFM edition of the same translation and
merged in at build time (only the structure; the verse text stays the getbible
`cus` text, and editorial section headings `\\s1` are intentionally dropped).

- **Source:** ebible.org `cmn-cu89s` (新标点和合本, Chinese Union New Punctuation,
  simplified), USFM bundle — <https://ebible.org/Scriptures/cmn-cu89s_usfm.zip>
  (details: <https://ebible.org/find/details.php?id=cmn-cu89s>).
- **License:** Public Domain (stated on the ebible.org details page).
- **Downloaded:** 2026-06-17.
- **Extraction:** `extract_paragraphs.py` walks the USFM and records, per
  book/chapter, the verse numbers that begin a paragraph — any paragraph/poetry
  marker (`\\p`, `\\m`, `\\q…`, list items, etc.; `\\nb` excluded) plus verse 1 of
  every chapter. Output: `paragraphs_cuv.json`.

To reproduce the paragraph map:

    curl -sL -o cmn-cu89s_usfm.zip https://ebible.org/Scriptures/cmn-cu89s_usfm.zip
    mkdir -p cuvs_usfm && unzip -q cmn-cu89s_usfm.zip -d cuvs_usfm
    python3 extract_paragraphs.py cuvs_usfm paragraphs_cuv.json

> **FTS note:** `verses_fts` uses the FTS5 `trigram` tokenizer so Chinese
> substring/phrase search works (the default `unicode61` tokenizer does not
> segment CJK runs). The trigram index covers queries of **3 or more
> characters**: `verses_fts MATCH '神创造'` and trigram-accelerated
> `text LIKE '%神创造%'` both work and are fast. Queries **shorter than 3
> characters** (e.g. `神`, `起初`) produce no trigrams, so `MATCH` returns
> nothing and `LIKE` falls back to a full scan. For 1–2 character searches,
> query the `verses` table directly with `text LIKE '%…%'` — a full scan over
> 31,103 verses is only a few ms.

Raw `source_*.json` / `raw_download.json` are gitignored; only the built
`bible.sqlite` and the converter are committed.

## Downloadable translations (Phase 4)

Build standalone per-translation databases with the same tool, then generate
the manifest:

    # Sources from getbible.net v2 (public domain): kjv, web
    curl -sL -o raw_kjv.json https://api.getbible.net/v2/kjv.json
    curl -sL -o raw_web.json https://api.getbible.net/v2/web.json
    python3 convert_source.py raw_kjv.json source_kjv.json   # if conversion needed
    python3 convert_source.py raw_web.json source_web.json   # if conversion needed
    python3 build_bible_db.py source_kjv.json kjv.sqlite kjv
    python3 build_bible_db.py source_web.json web.sqlite web

    # base_url = the GitHub Release asset download prefix
    python3 build_manifest.py \
      https://github.com/OWNER/REPO/releases/download/translations-v1 \
      ../translations/manifest.json

### Provenance & license
- **KJV** — King James Version (1611). Public domain. Source: getbible.net v2 `kjv`.
- **WEB** — World English Bible. Public domain (explicitly released). Source: getbible.net v2 `web`.

### Deploy
1. Create a GitHub Release tagged `translations-v1`; upload `kjv.sqlite`, `web.sqlite` as assets.
2. Commit `translations/manifest.json` (served via raw.githubusercontent.com).
3. Set `translationManifestURL` in `ContentView.swift` to that raw URL.
