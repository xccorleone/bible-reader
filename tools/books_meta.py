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


# Common abbreviation → book number mapping (lowercase).
ABBREV_TO_NUMBER: dict[str, int] = {
    "gn": 1, "ex": 2, "lv": 3, "nm": 4, "dt": 5, "jos": 6, "jdg": 7, "ru": 8,
    "1sm": 9, "2sm": 10, "1kgs": 11, "2kgs": 12, "1chr": 13, "2chr": 14,
    "ezr": 15, "neh": 16, "est": 17, "job": 18, "ps": 19, "prv": 20, "eccl": 21,
    "sg": 22, "is": 23, "jer": 24, "lam": 25, "ez": 26, "dn": 27, "hos": 28,
    "jl": 29, "am": 30, "ob": 31, "jon": 32, "mi": 33, "na": 34, "hb": 35,
    "zep": 36, "hg": 37, "zec": 38, "mal": 39,
    "mt": 40, "mk": 41, "lk": 42, "jn": 43, "acts": 44, "rom": 45,
    "1cor": 46, "2cor": 47, "gal": 48, "eph": 49, "phil": 50, "col": 51,
    "1thes": 52, "2thes": 53, "1tm": 54, "2tm": 55, "tit": 56, "phlm": 57,
    "heb": 58, "jas": 59, "1pt": 60, "2pt": 61, "1jn": 62, "2jn": 63,
    "3jn": 64, "jude": 65, "rv": 66,
}
