#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/MyMathpix.app"
app_binary="$app_dir/Contents/MacOS/MyMathpix"
acceptance_dir="${HOME}/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket01Acceptance"
evidence_file="$acceptance_dir/evidence.json"
relaunch_marker="$acceptance_dir/relaunch-mode.txt"
mode="${1:-launch}"
scenario="${2:-}"

find_app_pid() {
    pgrep -f "$app_binary" | head -n 1
}

write_relaunch_marker() {
    local marker_value="$1"
    local temporary_marker="$relaunch_marker.tmp.$$"
    umask 077
    mkdir -p "$acceptance_dir"
    printf '%s\n' "$marker_value" >"$temporary_marker"
    chmod 600 "$temporary_marker"
    mv -f "$temporary_marker" "$relaunch_marker"
}

verify_bundle() {
    codesign --verify --deep --strict "$app_dir"
    entitlements="$(codesign -d --entitlements :- "$app_dir" 2>/dev/null)"
    if [[ "$entitlements" != *"com.apple.security.app-sandbox"* ]]; then
        printf 'RED: App Sandbox entitlement is missing\n' >&2
        exit 1
    fi
}

launch_and_wait() {
    local marker_value="$1"
    shift
    if existing_pid="$(find_app_pid)" && [[ -n "$existing_pid" ]]; then
        printf 'BLOCKED: MyMathpix is already running (pid=%s); quit it before starting an isolated acceptance run\n' "$existing_pid" >&2
        exit 2
    fi
    write_relaunch_marker "$marker_value"
    launch_epoch="$(date +%s)"
    open -n "$app_dir" --args "$@"
    app_pid=""
    for _ in {1..100}; do
        app_pid="$(find_app_pid || true)"
        [[ -n "$app_pid" ]] && break
        sleep 0.1
    done
    if [[ -z "$app_pid" ]]; then
        rm -f "$relaunch_marker"
        printf 'RED: LaunchServices did not expose the Ticket 01 acceptance process\n' >&2
        exit 1
    fi
    for _ in {1..50}; do
        if [[ -f "$evidence_file" ]] && (( $(stat -f %m "$evidence_file") >= launch_epoch )); then
            break
        fi
        sleep 0.1
    done
    if [[ ! -f "$evidence_file" ]] || (( $(stat -f %m "$evidence_file") < launch_epoch )); then
        kill "$app_pid" >/dev/null 2>&1 || true
        rm -f "$relaunch_marker"
        printf 'RED: signed App did not initialize redacted Ticket 01 evidence\n' >&2
        exit 1
    fi
}

verify_safe_evidence_schema() {
    jq -e '
        (keys - [
            "active_display_count", "canonical_markdown_matches_fixture",
            "canonical_markdown_visible", "capture_completed",
            "capture_triggered_by_global_shortcut", "expected_pixel_height",
            "expected_pixel_width", "failure_code", "fields_approved",
            "fixture_valid", "guard_band_absent", "last_failure_code", "overlay_dismissed",
            "phase", "pixel_geometry_preserved", "png_pixel_height",
            "png_pixel_width", "png_valid", "poll_count", "preview_visible",
            "recent_history_count", "recent_history_visible",
            "recovery_probe_started", "recognizing_was_visible",
            "rendered_formula_visible", "rendered_table_visible", "result_complete",
            "result_editor_visible", "schema", "second_capture_blocked",
            "selected_display_scale", "selected_display_was_secondary",
            "selection_point_height", "selection_point_width", "submit_count",
            "original_snippet_visible", "distinct_display_scale_count"
        ] | length) == 0 and
        ([to_entries[].value | type] | all(. != "array" and . != "object"))
    ' "$evidence_file" >/dev/null
}

case "$mode" in
    launch|launch-secondary)
        verify_bundle
        launch_and_wait acceptance --ticket01-acceptance

        printf 'TICKET01_ACCEPTANCE_READY pid=%s\n' "$app_pid"
        printf 'FIXTURE=%s\n' "$repo_dir/scripts/ticket01_fixture.html"
        if [[ "$mode" == "launch-secondary" ]]; then
            printf 'ACTION=Move the fixture to a real secondary display. Keep the MyMathpix window fully covering the colored target, press Control-Command-M, drag just inside the green border so all four markers and the patterned center are included but no red guard is included, release, then press the shortcut once more while Recognizing is visible.\n'
        else
            printf 'ACTION=On a Retina display, keep the MyMathpix window fully covering the colored target, press Control-Command-M, drag just inside the green border so all four markers and the patterned center are included but no red guard is included, release, then press the shortcut once more while Recognizing is visible.\n'
        fi
        ;;
    verify|verify-secondary)
        app_pid="$(find_app_pid || true)"
        if [[ -z "$app_pid" ]] || ! kill -0 "$app_pid" >/dev/null 2>&1; then
            printf 'RED: acceptance App process is not alive\n' >&2
            exit 1
        fi
        jq -e '
            .schema == 4 and
            .phase == "complete" and
            .capture_triggered_by_global_shortcut == true and
            .capture_completed == true and
            .overlay_dismissed == true and
            .recognizing_was_visible == true and
            .second_capture_blocked == true and
            .submit_count == 1 and
            .poll_count >= 2 and
            .png_valid == true and
            .fields_approved == true and
            .fixture_valid == true and
            .guard_band_absent == true and
            .result_complete == true and
            .pixel_geometry_preserved == true and
            .png_pixel_width == .expected_pixel_width and
            .png_pixel_height == .expected_pixel_height and
            .selection_point_width >= 4 and
            .selection_point_height >= 4 and
            .selected_display_scale > 0 and
            .recent_history_count == 1 and
            .result_editor_visible == true and
            .original_snippet_visible == true and
            .canonical_markdown_visible == true and
            .canonical_markdown_matches_fixture == true and
            .preview_visible == true and
            .rendered_formula_visible == true and
            .rendered_table_visible == true and
            .recent_history_visible == true
        ' "$evidence_file" >/dev/null
        if [[ "$mode" == "verify-secondary" ]]; then
            jq -e '
                .active_display_count >= 2 and
                .selected_display_was_secondary == true
            ' "$evidence_file" >/dev/null
        else
            jq -e '.selected_display_scale >= 2' "$evidence_file" >/dev/null
        fi
        verify_safe_evidence_schema
        printf 'TICKET01_SIGNED_APP_OK mode=%s pid=%s submit=1 polls=multiple recent_history=1 ui=yes redacted=yes\n' "$mode" "$app_pid"
        ;;
    launch-scenario)
        case "$scenario" in
            permission-not-determined|permission-denied|permission-revoked|capture-api-failure|display-disappearance|cancellation|tiny-selection) ;;
            *)
                printf 'BLOCKED: unknown Ticket 01 scenario: %s\n' "$scenario" >&2
                exit 2
                ;;
        esac
        verify_bundle
        launch_and_wait "scenario:$scenario" --ticket01-acceptance "--ticket01-scenario=$scenario"
        printf 'TICKET01_SCENARIO_READY scenario=%s pid=%s\n' "$scenario" "$app_pid"
        if [[ "$scenario" == permission-* ]]; then
            printf 'ACTION=Prepare the named real macOS Screen Recording state first, invoke Control-Command-M, and confirm the process survives with a visible explanation. These permission scenarios use the real system permission provider, not an injected denial.\n'
        else
            printf 'ACTION=Complete the named failure or cancellation once, dismiss its explanation if shown, then press Control-Command-M again to prove the App is immediately operable. Leave the second selection overlay open.\n'
        fi
        ;;
    verify-scenario)
        app_pid="$(find_app_pid || true)"
        if [[ -z "$app_pid" ]] || ! kill -0 "$app_pid" >/dev/null 2>&1; then
            printf 'RED: scenario App process is not alive\n' >&2
            exit 1
        fi
        expected_code="$scenario"
        case "$scenario" in
            permission-not-determined|permission-denied|permission-revoked)
                expected_code="permission_denied"
                ;;
            capture-api-failure)
                expected_code="capture_api_failure"
                ;;
            display-disappearance)
                expected_code="display_unavailable"
                ;;
            tiny-selection)
                expected_code="selection_too_small"
                ;;
            cancellation)
                expected_code=""
                ;;
        esac
        if [[ "$scenario" == permission-* ]]; then
            jq -e --arg code "$expected_code" '
                .phase == "failed" and
                .failure_code == $code and
                .capture_triggered_by_global_shortcut == true and
                .recovery_probe_started == false and
                .recent_history_count == 0 and
                .submit_count == 0
            ' "$evidence_file" >/dev/null
        elif [[ "$scenario" == "cancellation" ]]; then
            jq -e '
                .phase == "selecting" and
                .capture_triggered_by_global_shortcut == true and
                .recovery_probe_started == true and
                .recent_history_count == 0 and
                .submit_count == 0 and
                .failure_code == null
            ' "$evidence_file" >/dev/null
        else
            jq -e --arg code "$expected_code" '
                .phase == "selecting" and
                .failure_code == null and
                .last_failure_code == $code and
                .capture_triggered_by_global_shortcut == true and
                .recovery_probe_started == true and
                .recent_history_count == 0 and
                .submit_count == 0
            ' "$evidence_file" >/dev/null
        fi
        verify_safe_evidence_schema
        if [[ "$scenario" == permission-* ]]; then
            printf 'TICKET01_SCENARIO_OK scenario=%s pid=%s recent_history=0 submits=0 explanation=yes redacted=yes\n' "$scenario" "$app_pid"
        else
            printf 'TICKET01_SCENARIO_OK scenario=%s pid=%s recent_history=0 submits=0 recovery_overlay=yes redacted=yes\n' "$scenario" "$app_pid"
        fi
        ;;
    stop)
        app_pid="$(find_app_pid || true)"
        if [[ -n "$app_pid" ]]; then
            kill "$app_pid"
            while kill -0 "$app_pid" >/dev/null 2>&1; do sleep 0.1; done
        fi
        rm -f "$relaunch_marker"
        printf 'TICKET01_ACCEPTANCE_STOPPED\n'
        ;;
    *)
        printf 'Usage: %s [launch|verify|launch-secondary|verify-secondary|launch-scenario NAME|verify-scenario NAME|stop]\n' "$0" >&2
        exit 2
        ;;
esac
