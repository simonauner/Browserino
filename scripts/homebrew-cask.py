#!/usr/bin/env python3
"""Render the Lotsen cask using the checksum of the ad hoc signed ZIP."""
import hashlib
from pathlib import Path
import re
import sys


def render(version, archive):
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Expected a semantic version such as 1.4.1")
    with archive.open("rb") as source:
        checksum = hashlib.file_digest(source, "sha256").hexdigest()
    return f'''cask "lotsen" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/simonauner/lotsen/releases/download/v#{{version}}/Lotsen.zip"
  name "Lotsen"
  desc "Browser selector with profiles and link routing rules"
  homepage "https://github.com/simonauner/lotsen"

  depends_on macos: :sonoma

  app "Lotsen.app"

  caveats <<~EOS
    Lotsen is ad hoc signed and is not notarized by Apple.
    If macOS blocks the first launch, try opening Lotsen, then use
    System Settings > Privacy & Security > Open Anyway if you trust this download.
  EOS
end
'''


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} VERSION Lotsen.zip")
    print(render(sys.argv[1], Path(sys.argv[2])), end="")
