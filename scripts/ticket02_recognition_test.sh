#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_binary="$repo_dir/dist/MyMathpix.app/Contents/MacOS/MyMathpix"
output_file="$(mktemp /private/tmp/mymathpix-ticket02-recognition.XXXXXX)"
trap 'rm -f "$output_file"' EXIT

if [[ ! -x "$app_binary" ]]; then
    printf 'RED: signed App binary is missing\n' >&2
    exit 1
fi

set +e
"$app_binary" --ticket02-recognition-self-test >"$output_file" 2>&1
exit_status=$?
set -e

if [[ "$exit_status" -ne 0 ]] || ! grep -Fxq 'TICKET02_RECOGNITION_OK' "$output_file"; then
    grep -E '^TICKET02_RECOGNITION_(FAIL|OK)$' "$output_file" || true
    printf 'RED: signed App Ticket 02 recognition contract failed (status=%s)\n' "$exit_status" >&2
    exit 1
fi

printf 'TICKET02_RECOGNITION_OK\n'
