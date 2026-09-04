#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h}"
"$repo_dir/scripts/build_app.sh"
open "$repo_dir/dist/MyMathpix.app"
