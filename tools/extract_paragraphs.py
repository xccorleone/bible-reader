"""Extract 和合本 paragraph (分段) structure from ebible.org USFM.

Input:  a directory of USFM files (cmn-cu89s_usfm.zip, 新标点和合本, Public Domain).
Output: paragraphs_cuv.json — for each book/chapter, the list of verse numbers
        that begin a new paragraph.

We take ONLY the paragraph structure, not the verse text (the app keeps its
existing getbible 'cus' text) and not the section headings (\\s1) — the reader
shows paragraph breaks without editorial sub-titles.

Output shape (string keys, JSON-friendly):
  { "1": { "1": [1, 3, 6, 9, ...], "2": [1, 4, ...] }, ... }
  book number -> chapter number -> sorted verse numbers that start a paragraph.

A verse "starts a paragraph" when a paragraph-level USFM marker (\\p, \\m, the
poetry \\q lines, list items, etc.) appears between the previous verse and this
one. Verse 1 of every chapter is always treated as a paragraph start.
"""
import json
import os
import re
import sys

# USFM 3-letter book code -> app book number (1..66, Genesis..Revelation).
BOOK_CODE_TO_NUMBER = {
    "GEN": 1, "EXO": 2, "LEV": 3, "NUM": 4, "DEU": 5, "JOS": 6, "JDG": 7,
    "RUT": 8, "1SA": 9, "2SA": 10, "1KI": 11, "2KI": 12, "1CH": 13, "2CH": 14,
    "EZR": 15, "NEH": 16, "EST": 17, "JOB": 18, "PSA": 19, "PRO": 20, "ECC": 21,
    "SNG": 22, "ISA": 23, "JER": 24, "LAM": 25, "EZK": 26, "DAN": 27, "HOS": 28,
    "JOL": 29, "AMO": 30, "OBA": 31, "JON": 32, "MIC": 33, "NAM": 34, "HAB": 35,
    "ZEP": 36, "HAG": 37, "ZEC": 38, "MAL": 39, "MAT": 40, "MRK": 41, "LUK": 42,
    "JHN": 43, "ACT": 44, "ROM": 45, "1CO": 46, "2CO": 47, "GAL": 48, "EPH": 49,
    "PHP": 50, "COL": 51, "1TH": 52, "2TH": 53, "1TI": 54, "2TI": 55, "TIT": 56,
    "PHM": 57, "HEB": 58, "JAS": 59, "1PE": 60, "2PE": 61, "1JN": 62, "2JN": 63,
    "3JN": 64, "JUD": 65, "REV": 66,
}

# Base paragraph-level markers (digit suffixes stripped) that begin a new
# paragraph/line. `\nb` ("no break") is deliberately excluded — it continues the
# previous paragraph.
PARA_BASE_TAGS = {
    "p", "m", "po", "pr", "cls", "pmo", "pm", "pmc", "pmr", "pi", "pc",
    "q", "qr", "qc", "qm", "qa", "qd",
    "li", "lim", "lh", "lf", "b",
}

_TAG_RE = re.compile(r"\\([a-z]+)\d*", re.IGNORECASE)


def _base_tag(line: str) -> str | None:
    m = _TAG_RE.match(line.lstrip())
    if not m:
        return None
    return m.group(1).rstrip("0123456789").lower()


def extract_file(path: str) -> tuple[int, dict[int, list[int]]]:
    """Returns (book_number, {chapter: [paragraph-start verse numbers]})."""
    book_number = None
    chapters: dict[int, list[int]] = {}
    chapter = 0
    pending = False  # a paragraph marker is waiting to attach to the next verse

    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if line.startswith("\\id "):
                code = line[4:].strip().split()[0].upper()
                book_number = BOOK_CODE_TO_NUMBER.get(code)
            elif line.startswith("\\c "):
                chapter = int(line[3:].strip().split()[0])
                chapters.setdefault(chapter, [])
                pending = True  # first verse of a chapter starts a paragraph
            elif line.startswith("\\v "):
                rest = line[3:].strip()
                verse = int(re.match(r"\d+", rest).group(0))
                if (pending or verse == 1) and verse not in chapters.get(chapter, []):
                    chapters.setdefault(chapter, []).append(verse)
                pending = False
            else:
                tag = _base_tag(line)
                if tag in PARA_BASE_TAGS:
                    pending = True

    if book_number is None:
        raise SystemExit(f"No recognized \\id book code in {path}")
    for ch in chapters:
        chapters[ch].sort()
    return book_number, chapters


def extract_dir(usfm_dir: str, out_path: str) -> None:
    result: dict[str, dict[str, list[int]]] = {}
    files = sorted(fn for fn in os.listdir(usfm_dir) if fn.endswith(".usfm"))
    total_breaks = 0
    for fn in files:
        book_number, chapters = extract_file(os.path.join(usfm_dir, fn))
        book_key = str(book_number)
        book_out = result.setdefault(book_key, {})
        for ch, verses in chapters.items():
            if verses:
                book_out[str(ch)] = verses
                total_breaks += len(verses)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False)
    print(f"Wrote {out_path}: {len(result)} books, {total_breaks} paragraph starts")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 extract_paragraphs.py <usfm_dir> <out.json>")
        sys.exit(1)
    extract_dir(sys.argv[1], sys.argv[2])
