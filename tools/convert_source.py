"""One-off converter: getbible.net v2 'cus' dump -> build_bible_db source shape.

Input:  raw_download.json  (getbible.net /v2/cus.json, 和合本 简体字, Public Domain)
Output: source_cuv.json   (array of 66 books, Genesis->Revelation order)

getbible v2 structure:
  { "books": [ { "nr": 1, "name": "创世记",
                 "chapters": [ { "chapter": 1,
                                 "verses": [ {"chapter":1,"verse":1,"text":"..."}, ... ] }, ... ] }, ... ] }

Target structure (build_bible_db.py expects):
  [ { "abbrev": "<str>", "chapters": [ ["v1 text", "v2 text", ...], ... ] }, ... ]
Array position = book number; chapter/verse numbers are implied by position.
"""
import json
import sys


def clean(text: str) -> str:
    # Strip BOM, normalize whitespace. The source has a leading BOM on some
    # strings and trailing spaces on every verse; verse text itself has no
    # embedded verse-number prefix in this source.
    text = text.replace("﻿", "")
    return text.strip()


def convert(src_path: str, out_path: str) -> None:
    with open(src_path, encoding="utf-8") as f:
        data = json.load(f)

    books = sorted(data["books"], key=lambda b: b["nr"])
    nrs = [b["nr"] for b in books]
    if nrs != list(range(1, 67)):
        raise SystemExit(f"Expected books numbered 1..66 with no gaps, got {nrs}")

    out = []
    gaps = []
    for b in books:
        chapters = sorted(b["chapters"], key=lambda c: c["chapter"])
        if [c["chapter"] for c in chapters] != list(range(1, len(chapters) + 1)):
            raise SystemExit(f"Chapter gap in book {b['nr']}")
        out_chapters = []
        for c in chapters:
            verses = sorted(c["verses"], key=lambda v: v["verse"])
            by_num = {v["verse"]: clean(v["text"]) for v in verses}
            last = verses[-1]["verse"]
            # Some translations omit verses (textual variants, e.g. WEB Luke
            # 17:36). Keep array position == verse number by filling gaps with
            # "". build_bible_db skips empty verses, so the DB carries no phantom
            # row and verse numbers stay aligned across translations (the app
            # renders a missing parallel verse as "—").
            missing = [n for n in range(1, last + 1) if n not in by_num]
            if missing:
                gaps.append((b["nr"], c["chapter"], missing))
            out_chapters.append([by_num.get(n, "") for n in range(1, last + 1)])
        out.append({"abbrev": clean(b["name"]), "chapters": out_chapters})

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)

    total = sum(len(ch) for bk in out for ch in bk["chapters"])
    print(f"Wrote {out_path}: {len(out)} books, {total} verse slots")
    if gaps:
        print(f"Filled {sum(len(m) for _, _, m in gaps)} omitted-verse gap(s): {gaps}")


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "raw_download.json"
    out = sys.argv[2] if len(sys.argv) > 2 else "source_cuv.json"
    convert(src, out)
