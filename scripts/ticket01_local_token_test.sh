#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_binary="$repo_dir/dist/MyMathpix.app/Contents/MacOS/MyMathpix"
output_file="$(mktemp /private/tmp/mymathpix-ticket01-local-token.XXXXXX)"
trap 'rm -f "$output_file"' EXIT

set +e
"$app_binary" --ticket01-local-token-self-test >"$output_file" 2>&1
exit_status=$?
set -e

if [[ "$exit_status" -ne 0 ]] || ! grep -Fxq 'TICKET01_LOCAL_TOKEN_OK' "$output_file"; then
    grep -E '^TICKET01_LOCAL_TOKEN_(FAIL|OK)$' "$output_file" || true
    printf 'RED: signed App local token store contract failed (status=%s)\n' "$exit_status" >&2
    exit 1
fi

printf 'TICKET01_LOCAL_TOKEN_OK\n'
