import hashlib
import json
import os
import tempfile
import unittest

import build_manifest


class BuildManifestTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.kjv = os.path.join(self.dir, "kjv.sqlite")
        with open(self.kjv, "wb") as f:
            f.write(b"fake sqlite bytes")

    def test_entry_has_sha256_and_size(self):
        entry = build_manifest.entry_for(
            self.kjv, id="kjv", name_zh="英王钦定本", name_en="King James Version",
            abbrev="KJV", language="en", base_url="https://e.com/dl")
        expected = hashlib.sha256(b"fake sqlite bytes").hexdigest()
        self.assertEqual(entry["sha256"], expected)
        self.assertEqual(entry["bytes"], len(b"fake sqlite bytes"))
        self.assertEqual(entry["url"], "https://e.com/dl/kjv.sqlite")
        self.assertEqual(entry["id"], "kjv")

    def test_manifest_has_schema_version(self):
        manifest = build_manifest.build([
            (self.kjv, "kjv", "英王钦定本", "King James Version", "KJV", "en"),
        ], base_url="https://e.com/dl")
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(len(manifest["translations"]), 1)
        # round-trips as JSON
        json.dumps(manifest)


if __name__ == "__main__":
    unittest.main()
