# tools/test_extract_paragraphs.py
import json
import os
import tempfile
import unittest

import extract_paragraphs

GEN_USFM = """\\id GEN Test
\\h 创世记
\\c 1
\\s1 神的创造
\\p
\\v 1 起初，神创造天地。
\\v 2 地是空虚混沌。
\\p
\\v 3 神说：要有光。
\\c 2
\\p
\\v 1 天地万物都造齐了。
\\nb
\\v 2 到第七日。
"""

PSALM_USFM = """\\id PSA Test
\\c 1
\\q1
\\v 1 不从恶人的计谋
\\q2
\\v 2 惟喜爱耶和华的律法
"""


class ExtractParagraphTests(unittest.TestCase):
    def _run(self, files: dict[str, str]) -> dict:
        with tempfile.TemporaryDirectory() as d:
            for name, content in files.items():
                with open(os.path.join(d, name), "w", encoding="utf-8") as f:
                    f.write(content)
            out = os.path.join(d, "out.json")
            extract_paragraphs.extract_dir(d, out)
            with open(out, encoding="utf-8") as f:
                return json.load(f)

    def test_p_markers_and_chapter_starts(self):
        result = self._run({"02-GEN.usfm": GEN_USFM})
        # GEN -> book 1. v1 and v3 start paragraphs (\p before each); v2 does not.
        self.assertEqual(result["1"]["1"], [1, 3])

    def test_nb_does_not_start_paragraph(self):
        result = self._run({"02-GEN.usfm": GEN_USFM})
        # Chapter 2: v1 starts (after \p); v2 follows \nb so it must NOT start one.
        self.assertEqual(result["1"]["2"], [1])

    def test_poetry_q_lines_start_paragraphs(self):
        result = self._run({"20-PSA.usfm": PSALM_USFM})
        # PSA -> book 19. Each \q line begins a new paragraph/line.
        self.assertEqual(result["19"]["1"], [1, 2])


if __name__ == "__main__":
    unittest.main()
