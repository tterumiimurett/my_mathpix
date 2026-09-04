#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_binary="$repo_dir/dist/MyMathpix.app/Contents/MacOS/MyMathpix"
output_file="$(mktemp /private/tmp/mymathpix-ticket01-mock.XXXXXX)"
trap 'rm -f "$output_file"' EXIT

if [[ ! -x "$app_binary" ]]; then
    printf 'RED: signed App binary is missing\n' >&2
    exit 1
fi

"$app_binary" --ticket01-mock-recognition-self-test >"$output_file" 2>&1 &
app_pid=$!

for _ in {1..100}; do
    if ! kill -0 "$app_pid" >/dev/null 2>&1; then
        break
    fi
    sleep 0.05
done

if kill -0 "$app_pid" >/dev/null 2>&1; then
    kill "$app_pid" >/dev/null 2>&1 || true
    wait "$app_pid" >/dev/null 2>&1 || true
    printf 'RED: mock recognition self-test did not terminate\n' >&2
    exit 1
fi

set +e
wait "$app_pid"
exit_status=$?
set -e

expected='TICKET01_MOCK_PROTOCOL_OK submit=1 polls=5 png=yes fields=yes fixture=yes guard=yes result=yes'
if [[ "$exit_status" -ne 0 ]] || ! grep -Fxq "$expected" "$output_file"; then
    grep -E '^TICKET01_MOCK_PROTOCOL_(FAIL|OK) ' "$output_file" || true
    printf 'RED: expected safe mock protocol evidence was not emitted (status=%s)\n' "$exit_status" >&2
    exit 1
fi

printf '%s\n' "$expected"
