"""Generate manifest.json for downloadable Bible translations.

Each translation is a self-contained .sqlite (built by build_bible_db.py).
This computes sha256 + byte size per file and emits the manifest the app
fetches. Files are hosted as GitHub Release assets; base_url is that release's
download prefix.
"""
import hashlib
import json
import os
import sys

SCHEMA_VERSION = 1


def entry_for(path, *, id, name_zh, name_en, abbrev, language, base_url):
    with open(path, "rb") as fh:
        data = fh.read()
    return {
        "id": id,
        "nameZH": name_zh,
        "nameEN": name_en,
        "abbrev": abbrev,
        "language": language,
        "url": f"{base_url.rstrip('/')}/{os.path.basename(path)}",
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def build(specs, *, base_url):
    """specs: list of (path, id, name_zh, name_en, abbrev, language)."""
    return {
        "schemaVersion": SCHEMA_VERSION,
        "translations": [
            entry_for(path, id=i, name_zh=zh, name_en=en, abbrev=ab,
                      language=lang, base_url=base_url)
            for (path, i, zh, en, ab, lang) in specs
        ],
    }


# Catalog for Phase 4: KJV + WEB. Paths are relative to this tools/ dir.
CATALOG = [
    ("kjv.sqlite", "kjv", "英王钦定本", "King James Version", "KJV", "en"),
    ("web.sqlite", "web", "世界英文圣经", "World English Bible", "WEB", "en"),
]


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 build_manifest.py <base_url> <out_manifest.json>")
        sys.exit(1)
    base_url, out = sys.argv[1], sys.argv[2]
    script_dir = os.path.dirname(os.path.abspath(__file__))
    specs = [(os.path.join(script_dir, filename), id, zh, en, ab, lang)
             for (filename, id, zh, en, ab, lang) in CATALOG]
    manifest = build(specs, base_url=base_url)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"Wrote {out} ({len(manifest['translations'])} translations)")
