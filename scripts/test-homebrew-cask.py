import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "homebrew_cask", Path(__file__).resolve().parents[1] / "scripts/homebrew-cask.py"
)
cask = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cask)


class HomebrewCaskTests(unittest.TestCase):
    def test_release_url_and_checksum(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "Lotsen.zip"
            archive.write_bytes(b"stapled release")
            rendered = cask.render("1.4.1", archive)
        self.assertIn('version "1.4.1"', rendered)
        self.assertIn(hashlib.sha256(b"stapled release").hexdigest(), rendered)
        self.assertIn('/download/v#{version}/Lotsen.zip"', rendered)
        self.assertIn('app "Lotsen.app"', rendered)
        self.assertIn('depends_on macos: :sonoma', rendered)

    def test_rejects_invalid_versions_before_reading_archive(self):
        for version in ('1.2', 'v1.2.3', '01.2.3', '1.2.3"\nend', '1.2.3-beta'):
            with self.subTest(version=version), self.assertRaises(ValueError):
                cask.render(version, Path("missing.zip"))


if __name__ == "__main__":
    unittest.main()
