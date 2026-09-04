#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/MyMathpix.app"
app_binary="$app_dir/Contents/MacOS/MyMathpix"
evidence_dir="$repo_dir/.scratch/personal-mvp/evidence/ticket-01"
evidence_file="$evidence_dir/baseline-process-termination.txt"

if [[ ! -x "$app_binary" ]]; then
    printf 'BLOCKED: signed App binary is missing at %s\n' "$app_binary" >&2
    exit 2
fi

if pgrep -f "$app_binary" >/dev/null 2>&1; then
    printf 'BLOCKED: MyMathpix is already running. Quit it before this isolated reproduction.\n' >&2
    exit 2
fi

mkdir -p "$evidence_dir"

signature_status="invalid"
if codesign --verify --deep --strict "$app_dir" >/dev/null 2>&1; then
    signature_status="valid"
fi

"$app_binary" >/dev/null 2>&1 &
app_pid=$!

for _ in {1..40}; do
    if kill -0 "$app_pid" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

if ! kill -0 "$app_pid" >/dev/null 2>&1; then
    wait "$app_pid" || launch_status=$?
    printf 'BLOCKED: MyMathpix exited during launch with status %s.\n' "${launch_status:-0}" >&2
    exit 2
fi

printf 'READY_FOR_HITL pid=%s\n' "$app_pid"
printf 'ACTION: Press Control-Command-M, drag a rectangle over non-sensitive content, and release within 90 seconds.\n'

deadline=$((SECONDS + 90))
while kill -0 "$app_pid" >/dev/null 2>&1 && (( SECONDS < deadline )); do
    sleep 0.25
done

post_selection_alive="no"
exit_status="unknown"
if kill -0 "$app_pid" >/dev/null 2>&1; then
    post_selection_alive="yes"
    exit_status="running-after-90-seconds"
else
    set +e
    wait "$app_pid"
    exit_status=$?
    set -e
fi

{
    printf 'artifact=safe-process-metadata-only\n'
    printf 'bundle=dist/MyMathpix.app\n'
    printf 'signature=%s\n' "$signature_status"
    printf 'pid=%s\n' "$app_pid"
    printf 'alive_before_shortcut=yes\n'
    printf 'alive_after_selection=%s\n' "$post_selection_alive"
    printf 'exit_status=%s\n' "$exit_status"
    printf 'contains_credentials=no\n'
    printf 'contains_snippet_pixels=no\n'
    printf 'contains_complete_recognition_output=no\n'
} > "$evidence_file"

printf '\n--- Captured ---\n'
printf 'EVIDENCE=%s\n' "$evidence_file"
printf 'ALIVE_AFTER_SELECTION=%s\n' "$post_selection_alive"
printf 'EXIT_STATUS=%s\n' "$exit_status"

if [[ "$post_selection_alive" == "no" ]]; then
    printf 'VERDICT=RED_PROCESS_TERMINATION\n'
    exit 1
fi

printf 'VERDICT=INCONCLUSIVE_HITL_TIMEOUT_PROCESS_STILL_ALIVE\n'
exit 3
