#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="${MYMATHPIX_ACCEPTANCE_APP:-$repo_dir/dist/MyMathpixTicket03Acceptance.app}"
acceptance_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_dir/Contents/Info.plist")"
app_binary="$app_dir/Contents/MacOS/MyMathpix"
acceptance_dir="${HOME}/Library/Containers/$acceptance_bundle_id/Data/Library/Application Support/MyMathpix/Ticket03Acceptance"
evidence_file="$acceptance_dir/evidence.json"
session_file="$acceptance_dir/run-state.txt"
mode="${1:-launch}"
format="${2:-}"
stage="${3:-edited}"

find_app_pid() {
    pgrep -f "$app_binary.*--ticket03-acceptance" | head -n 1
}

bundle_cdhash() {
    codesign -dvvv "$app_dir" 2>&1 | sed -n 's/^CDHash=//p' | head -n 1
}

verify_bundle() {
    codesign --verify --deep --strict "$app_dir"
    entitlements="$(codesign -d --entitlements :- "$app_dir" 2>/dev/null)"
    if [[ "$entitlements" != *"com.apple.security.app-sandbox"* ]]; then
        printf 'RED: App Sandbox entitlement is missing\n' >&2
        exit 1
    fi
}

case "$mode" in
    launch)
        verify_bundle
        if existing_pid="$(find_app_pid)" && [[ -n "$existing_pid" ]]; then
            printf 'BLOCKED: Ticket 03 acceptance App is already running (pid=%s)\n' "$existing_pid" >&2
            exit 2
        fi
        mkdir -p "$acceptance_dir"
        rm -f "$evidence_file" "$session_file"
        run_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
        launch_epoch="$(date +%s)"
        open -n "$app_dir" --args --ticket03-acceptance "--ticket03-run-id=$run_id"
        app_pid=""
        for _ in {1..100}; do
            app_pid="$(find_app_pid || true)"
            [[ -n "$app_pid" ]] && break
            sleep 0.1
        done
        if [[ -z "$app_pid" ]]; then
            printf 'RED: LaunchServices did not expose the Ticket 03 acceptance process\n' >&2
            exit 1
        fi
        umask 077
        printf '%s|%s|%s\n' "$run_id" "$app_pid" "$(bundle_cdhash)" >"$session_file"
        chmod 600 "$session_file"
        for _ in {1..100}; do
            if [[ -f "$evidence_file" ]] && (( $(stat -f %m "$evidence_file") >= launch_epoch )); then
                break
            fi
            sleep 0.1
        done
        if [[ ! -f "$evidence_file" ]] ||
           ! jq -e --arg run_id "$run_id" --argjson process_id "$app_pid" '
                .schema == 1 and .acceptance_run_id == $run_id and .process_id == $process_id
           ' "$evidence_file" >/dev/null; then
            printf 'RED: signed App did not initialize bound Ticket 03 evidence\n' >&2
            exit 1
        fi
        printf 'TICKET03_ACCEPTANCE_READY pid=%s\n' "$app_pid"
        printf 'ACTION=Edit Canonical Markdown, confirm the offline formula/table preview changes, and exercise each Copy Format. Exercise Markdown / Lark / Notion on both declared fixture stages and inspect each public clipboard immediately; Notion inline math remains a known deferred defect, with no destination Native Paste guarantee.\n'
        ;;
    verify)
        verify_bundle
        if [[ ! -r "$session_file" ]]; then
            printf 'RED: Ticket 03 acceptance run state is missing\n' >&2
            exit 1
        fi
        IFS='|' read -r run_id original_pid session_cdhash <"$session_file"
        if [[ -z "$session_cdhash" || "$session_cdhash" != "$(bundle_cdhash)" ]]; then
            printf 'RED: signed candidate changed after launch\n' >&2
            exit 1
        fi
        app_pid="$(find_app_pid || true)"
        if [[ -z "$app_pid" ]] || [[ "$app_pid" != "$original_pid" ]] ||
           ! kill -0 "$app_pid" >/dev/null 2>&1; then
            printf 'RED: Ticket 03 acceptance App process is not alive\n' >&2
            exit 1
        fi
        for _ in {1..200}; do
            if jq -e '.phase == "complete"' "$evidence_file" >/dev/null 2>&1; then break; fi
            sleep 0.1
        done
        jq -e --arg run_id "$run_id" --argjson process_id "$app_pid" '
            .schema == 1 and
            .acceptance_run_id == $run_id and
            .process_id == $process_id and
            .phase == "complete" and
            .result_editor_visible == true and
            .original_snippet_visible == true and
            .canonical_markdown_visible == true and
            .copy_formats_visible == true and
            .native_paste_boundary_visible == true and
            .initial_preview_visible == true and
            .edited_source_visible == true and
            .edited_preview_visible == true and
            .rendered_formula_visible == true and
            .rendered_table_visible == true and
            .offline_policy_present == true and
            .markdown_copied == true and
            .lark_copied == true and
            .notion_copied == true and
            ([to_entries[].value | type] | all(. != "array" and . != "object"))
        ' "$evidence_file" >/dev/null
        printf 'TICKET03_SIGNED_APP_OK pid=%s editor=yes edit_preview=yes offline=yes copy_formats=markdown-lark-notion destination_acceptance=not-asserted redacted=yes\n' "$app_pid"
        ;;
    inspect-copy)
        case "$format" in
            markdown|lark|notion) ;;
            *)
                printf 'Usage: %s inspect-copy {markdown|lark|notion} [initial|edited]\n' "$0" >&2
                exit 2
                ;;
        esac
        app_pid="$(find_app_pid || true)"
        if [[ -z "$app_pid" ]] || ! kill -0 "$app_pid" >/dev/null 2>&1; then
            printf 'RED: Ticket 03 acceptance App process is not alive\n' >&2
            exit 1
        fi
        case "$stage" in initial|edited) ;; *) printf 'RED: unknown fixture stage\n' >&2; exit 2 ;; esac
        "$app_binary" "--ticket03-inspect-pasteboard=$format" "--ticket03-inspect-stage=$stage"
        ;;
    stop)
        app_pid="$(find_app_pid || true)"
        if [[ -n "$app_pid" ]]; then
            kill "$app_pid"
            while kill -0 "$app_pid" >/dev/null 2>&1; do sleep 0.1; done
        fi
        printf 'TICKET03_ACCEPTANCE_STOPPED\n'
        ;;
    *)
        printf 'Usage: %s [launch|verify|inspect-copy|stop] [format]\n' "$0" >&2
        exit 2
        ;;
esac
