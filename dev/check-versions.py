"""Keep Python, npm and the bundled extension at the GAP package version."""

import json
from pathlib import Path
import re


root = Path(__file__).resolve().parents[1]
match = re.search(r'^Version\s*:=\s*"([^"]+)"',
                  (root / "PackageInfo.g").read_text(), re.MULTILINE)
if match is None:
    raise SystemExit("Cannot read Version from PackageInfo.g")
version = match.group(1)
for name in ("package.json", "package-lock.json", "gap_jupyter_kernel/labextension/package.json"):
    metadata = json.loads((root / name).read_text())
    versions = [metadata["version"]]
    if name == "package-lock.json":
        versions.append(metadata["packages"][""]["version"])
    if any(value != version for value in versions):
        raise SystemExit(f"{name}: {versions} disagree with PackageInfo.g {version}")
print(f"Package versions agree: {version}")
