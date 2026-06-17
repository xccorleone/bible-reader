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
    python3 convert_source.py raw_kjv.json source_kjv.json   # if conversion needed
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
