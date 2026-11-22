#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
"$repo_dir/scripts/build_app.sh" >/dev/null

python3 - "$repo_dir" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix="mymathpix-markdown-converter.") as test_dir:
    # Give the signed fixture a container distinct from the normal installation.
    app = Path(test_dir) / "MyMathpix.app"
    subprocess.run(["ditto", repo / "dist/MyMathpix.app", app], check=True)
    subprocess.run([
        "/usr/libexec/PlistBuddy", "-c",
        "Set :CFBundleIdentifier com.byterumi.mymathpix.markdownuitest",
        app / "Contents/Info.plist",
    ], check=True)
    subprocess.run([
        "codesign", "--force", "--deep", "--sign", "-", "--entitlements",
        repo / "Config/MyMathpix.entitlements", app,
    ], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", app], check=True)
    try:
        result = subprocess.run([
            app / "Contents/MacOS/MyMathpix", "--markdown-converter-self-test",
        ], timeout=20)
    except subprocess.TimeoutExpired:
        raise SystemExit("Markdown converter self-test timed out") from None
    raise SystemExit(result.returncode)
PY
