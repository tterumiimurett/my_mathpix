#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="${MYMATHPIX_ACCEPTANCE_APP:-$repo_dir/dist/MyMathpix.app}"
app_binary="$app_dir/Contents/MacOS/MyMathpix"
acceptance_dir="${HOME}/Library/Containers/com.byterumi.mymathpix/Data/Library/Application Support/MyMathpix/Ticket01Acceptance"
evidence_file="$acceptance_dir/evidence.json"
relaunch_marker="$acceptance_dir/relaunch-mode.txt"
session_file="$acceptance_dir/run-state.txt"
tcc_state_file="$acceptance_dir/tcc-state.txt"
mode="${1:-launch}"
scenario="${2:-}"

find_app_pid() {
    pgrep -f "$app_binary" | head -n 1
}

bundle_cdhash() {
    codesign -dvvv "$app_dir" 2>&1 | sed -n 's/^CDHash=//p' | head -n 1
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

write_session_state() {
    local run_id="$1"
    local original_pid="$2"
    local relaunch_policy="$3"
    local cdhash="$4"
    local temporary_session="$session_file.tmp.$$"
    umask 077
    printf '%s|%s|%s|%s\n' "$run_id" "$original_pid" "$relaunch_policy" "$cdhash" >"$temporary_session"
    chmod 600 "$temporary_session"
    mv -f "$temporary_session" "$session_file"
}

load_session_state() {
    if [[ ! -r "$session_file" ]]; then
        printf 'RED: Ticket 01 acceptance run state is missing\n' >&2
        exit 1
    fi
    IFS='|' read -r session_run_id original_pid relaunch_policy session_cdhash <"$session_file"
    if [[ ! "$session_run_id" =~ '^[0-9a-f-]{36}$' ]] ||
       [[ ! "$original_pid" =~ '^[0-9]+$' ]] ||
       [[ -z "$relaunch_policy" ]] ||
       [[ ! "$session_cdhash" =~ '^[0-9a-f]{40}$' ]]; then
        printf 'RED: Ticket 01 acceptance run state is invalid\n' >&2
        exit 1
    fi
    if [[ "$session_cdhash" != "$(bundle_cdhash)" ]]; then
        printf 'RED: signed App changed after this acceptance run was launched\n' >&2
        exit 1
    fi
}

write_tcc_state() {
    local state="$1"
    local origin="$2"
    local temporary_state="$tcc_state_file.tmp.$$"
    umask 077
    mkdir -p "$acceptance_dir"
    printf '%s|%s|%s|%s\n' "$state" "$(date +%s)" "$origin" "$(bundle_cdhash)" >"$temporary_state"
    chmod 600 "$temporary_state"
    mv -f "$temporary_state" "$tcc_state_file"
}

load_tcc_state() {
    if [[ ! -r "$tcc_state_file" ]]; then
        printf 'BLOCKED: the required real TCC predecessor state has not been verified\n' >&2
        exit 2
    fi
    IFS='|' read -r observed_tcc_state observed_tcc_epoch observed_tcc_origin observed_tcc_cdhash <"$tcc_state_file"
    if [[ ! "$observed_tcc_epoch" =~ '^[0-9]+$' ]] ||
       [[ ! "$observed_tcc_cdhash" =~ '^[0-9a-f]{40}$' ]]; then
        printf 'BLOCKED: the real TCC predecessor evidence is invalid or older than 30 minutes\n' >&2
        exit 2
    fi
    tcc_state_age=$(( $(date +%s) - observed_tcc_epoch ))
    if (( tcc_state_age < -5 )) || (( tcc_state_age > 1800 )); then
        printf 'BLOCKED: the real TCC predecessor evidence is invalid or older than 30 minutes\n' >&2
        exit 2
    fi
    if [[ "$observed_tcc_cdhash" != "$(bundle_cdhash)" ]]; then
        printf 'BLOCKED: the real TCC predecessor belongs to a different signed App build\n' >&2
        exit 2
    fi
}

require_tcc_state() {
    local expected_state="$1"
    load_tcc_state
    if [[ "$observed_tcc_state" != "$expected_state" ]]; then
        printf 'BLOCKED: expected real TCC state %s, last verified state is %s\n' "$expected_state" "$observed_tcc_state" >&2
        exit 2
    fi
}

require_no_running_app() {
    if existing_pid="$(find_app_pid)" && [[ -n "$existing_pid" ]]; then
        printf 'BLOCKED: MyMathpix is already running (pid=%s); quit it before changing or probing TCC state\n' "$existing_pid" >&2
        exit 2
    fi
}

screen_permission_probe() {
    "$app_binary" --ticket01-screen-permission-state
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
    local relaunch_policy="$1"
    shift
    if existing_pid="$(find_app_pid)" && [[ -n "$existing_pid" ]]; then
        printf 'BLOCKED: MyMathpix is already running (pid=%s); quit it before starting an isolated acceptance run\n' "$existing_pid" >&2
        exit 2
    fi
    mkdir -p "$acceptance_dir"
    run_id="$(uuidgen | tr '[:upper:]' '[:lower:]')"
    app_pid=""
    launch_committed="no"
    cleanup_incomplete_launch() {
        if [[ "$launch_committed" == "yes" ]]; then return; fi
        if [[ -n "$app_pid" ]] && kill -0 "$app_pid" >/dev/null 2>&1; then
            running_command="$(ps -p "$app_pid" -o command= 2>/dev/null || true)"
            if [[ "$running_command" == "$app_binary"* ]] &&
               [[ "$running_command" == *"--ticket01-run-id=$run_id"* ]]; then
                kill "$app_pid" >/dev/null 2>&1 || true
            fi
        fi
        rm -f "$relaunch_marker" "$session_file"
    }
    trap 'cleanup_incomplete_launch' EXIT
    trap 'cleanup_incomplete_launch; trap - EXIT INT TERM; exit 130' INT
    trap 'cleanup_incomplete_launch; trap - EXIT INT TERM; exit 143' TERM
    case "$relaunch_policy" in
        none)
            rm -f "$relaunch_marker"
            ;;
        acceptance)
            write_relaunch_marker "acceptance:$run_id"
            ;;
        scenario:*)
            write_relaunch_marker "$relaunch_policy:$run_id"
            ;;
        *)
            printf 'RED: invalid relaunch policy\n' >&2
            exit 1
            ;;
    esac
    launch_epoch="$(date +%s)"
    open -n "$app_dir" --args "$@" "--ticket01-run-id=$run_id"
    for _ in {1..100}; do
        app_pid="$(find_app_pid || true)"
        [[ -n "$app_pid" ]] && break
        sleep 0.1
    done
    if [[ -z "$app_pid" ]]; then
        printf 'RED: LaunchServices did not expose the Ticket 01 acceptance process\n' >&2
        exit 1
    fi
    write_session_state "$run_id" "$app_pid" "$relaunch_policy" "$(bundle_cdhash)"
    for _ in {1..50}; do
        if [[ -f "$evidence_file" ]] && (( $(stat -f %m "$evidence_file") >= launch_epoch )); then
            break
        fi
        sleep 0.1
    done
    if [[ ! -f "$evidence_file" ]] || (( $(stat -f %m "$evidence_file") < launch_epoch )); then
        printf 'RED: signed App did not initialize redacted Ticket 01 evidence\n' >&2
        exit 1
    fi
    if ! jq -e --arg run_id "$run_id" --argjson process_id "$app_pid" '
        .acceptance_run_id == $run_id and .process_id == $process_id
    ' "$evidence_file" >/dev/null; then
        printf 'RED: signed App evidence is not bound to the launched process and run\n' >&2
        exit 1
    fi
    launch_committed="yes"
    trap - EXIT INT TERM
}

verify_safe_evidence_schema() {
    jq -e '
        .schema == 6 and
        (keys - [
            "acceptance_run_id", "active_display_count", "canonical_markdown_matches_fixture",
            "canonical_markdown_visible", "capture_completed",
            "capture_triggered_by_global_shortcut", "captured_display_id", "expected_pixel_height",
            "expected_pixel_width", "failure_code", "fields_approved",
            "fixture_valid", "guard_band_absent", "last_failure_code", "overlay_dismissed",
            "main_window_visible_when_recognition_started",
            "permission_preflight_granted", "permission_request_attempted",
            "permission_request_granted", "phase", "pixel_geometry_preserved",
            "png_pixel_height", "process_id",
            "png_pixel_width", "png_valid", "poll_count", "preview_visible",
            "recent_history_count", "recent_history_visible",
            "recovery_probe_started", "recognizing_was_visible",
            "rendered_formula_visible", "rendered_table_visible", "result_complete",
            "result_editor_visible", "result_editor_window_display_matches_capture",
            "result_editor_window_presented", "result_editor_window_presented_after_completion",
            "result_editor_window_uses_visible_area_top_left_inset", "schema", "second_capture_blocked",
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
        launch_and_wait none --ticket01-acceptance

        printf 'TICKET01_ACCEPTANCE_READY pid=%s\n' "$app_pid"
        printf 'FIXTURE=%s\n' "$repo_dir/scripts/ticket01_fixture.html"
        if [[ "$mode" == "launch-secondary" ]]; then
            printf 'ACTION=Move the fixture to a real secondary display. Keep the MyMathpix window fully covering the colored target, press Control-Command-M, drag just inside the green border so all four markers and the patterned center are included but no red guard is included, release, then press the shortcut once more while the redacted evidence phase is recognizing (before completion). The App stays hidden during this capture-recognition phase; it opens the result only after completion.\n'
        else
            printf 'ACTION=On a Retina display, keep the MyMathpix window fully covering the colored target, press Control-Command-M, drag just inside the green border so all four markers and the patterned center are included but no red guard is included, release, then press the shortcut once more while the redacted evidence phase is recognizing (before completion). The App stays hidden during this capture-recognition phase; it opens the result only after completion.\n'
        fi
        ;;
    verify|verify-secondary)
        load_session_state
        app_pid="$(find_app_pid || true)"
        if [[ -z "$app_pid" ]] || ! kill -0 "$app_pid" >/dev/null 2>&1; then
            printf 'RED: acceptance App process is not alive\n' >&2
            exit 1
        fi
        if [[ "$relaunch_policy" != "none" ]] || [[ "$app_pid" != "$original_pid" ]]; then
            printf 'RED: authoritative capture process was replaced after launch (original=%s current=%s)\n' "$original_pid" "$app_pid" >&2
            exit 1
        fi
        jq -e --arg run_id "$session_run_id" --argjson process_id "$app_pid" '
            .schema == 6 and
            .acceptance_run_id == $run_id and
            .process_id == $process_id and
            .phase == "complete" and
            .capture_triggered_by_global_shortcut == true and
            .permission_preflight_granted == true and
            .permission_request_attempted == false and
            .permission_request_granted == null and
            .capture_completed == true and
            .overlay_dismissed == true and
            .main_window_visible_when_recognition_started == false and
            (.recognizing_was_visible | type) == "boolean" and
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
            and .result_editor_window_presented == true
            and .result_editor_window_presented_after_completion == true
            and .result_editor_window_display_matches_capture == true
            and .result_editor_window_uses_visible_area_top_left_inset == true
        ' "$evidence_file" >/dev/null
        if [[ "$mode" == "verify-secondary" ]]; then
            jq -e '
                .active_display_count >= 2 and
                .selected_display_was_secondary == true and
                .selected_display_scale >= 2
            ' "$evidence_file" >/dev/null
        else
            jq -e '.selected_display_scale >= 2' "$evidence_file" >/dev/null
        fi
        verify_safe_evidence_schema
        write_tcc_state granted "$session_run_id"
        recognizing_visible="$(jq -r '.recognizing_was_visible' "$evidence_file")"
        printf 'TICKET01_SIGNED_APP_OK mode=%s pid=%s submit=1 polls=multiple recent_history=1 result_ui=yes recognizing_visible=%s redacted=yes\n' "$mode" "$app_pid" "$recognizing_visible"
        ;;
    prepare-permission-not-determined)
        verify_bundle
        require_no_running_app
        rm -f "$relaunch_marker" "$session_file"
        tccutil reset ScreenCapture com.byterumi.mymathpix >/dev/null
        if [[ "$(screen_permission_probe)" != "TICKET01_SCREEN_PERMISSION granted=no" ]]; then
            printf 'RED: Screen Recording preflight remained granted after TCC reset\n' >&2
            exit 1
        fi
        write_tcc_state not-determined tccutil-reset
        printf 'TICKET01_TCC_PREPARED state=not-determined source=tccutil-reset redacted=yes\n'
        ;;
    prepare-permission-revoked)
        verify_bundle
        require_no_running_app
        require_tcc_state granted
        rm -f "$relaunch_marker" "$session_file"
        if [[ "$(screen_permission_probe)" != "TICKET01_SCREEN_PERMISSION granted=no" ]]; then
            printf 'BLOCKED: revoke Screen Recording for MyMathpix in System Settings, quit it, then rerun this preparation\n' >&2
            exit 2
        fi
        write_tcc_state revoked "after-granted:$observed_tcc_origin"
        printf 'TICKET01_TCC_PREPARED state=revoked source=granted-to-denied-transition redacted=yes\n'
        ;;
    launch-scenario)
        case "$scenario" in
            permission-not-determined|permission-denied|permission-revoked|capture-api-failure|display-disappearance|cancellation|tiny-selection) ;;
            *)
                printf 'BLOCKED: unknown Ticket 01 scenario: %s\n' "$scenario" >&2
                exit 2
                ;;
        esac
        case "$scenario" in
            permission-not-determined)
                require_tcc_state not-determined
                ;;
            permission-denied)
                require_tcc_state denied
                ;;
            permission-revoked)
                require_tcc_state revoked
                ;;
        esac
        verify_bundle
        relaunch_policy="none"
        if [[ "$scenario" == permission-* ]]; then
            relaunch_policy="scenario:$scenario"
        fi
        launch_and_wait "$relaunch_policy" --ticket01-acceptance "--ticket01-scenario=$scenario"
        printf 'TICKET01_SCENARIO_READY scenario=%s pid=%s\n' "$scenario" "$app_pid"
        if [[ "$scenario" == permission-* ]]; then
            printf 'ACTION=The named real macOS TCC predecessor state is recorded. Invoke Control-Command-M and confirm the process survives with a visible explanation. For not-determined, choose Don’t Allow in the real system prompt so the next denied-state run has an observed predecessor.\n'
        else
            printf 'ACTION=Complete the named failure or cancellation once, dismiss its explanation if shown, then press Control-Command-M again to prove the App is immediately operable. Leave the second selection overlay open.\n'
        fi
        ;;
    verify-scenario)
        trap 'rm -f "$relaunch_marker"' EXIT
        load_session_state
        app_pid="$(find_app_pid || true)"
        if [[ -z "$app_pid" ]] || ! kill -0 "$app_pid" >/dev/null 2>&1; then
            printf 'RED: scenario App process is not alive\n' >&2
            exit 1
        fi
        expected_relaunch_policy="none"
        if [[ "$scenario" == permission-* ]]; then
            expected_relaunch_policy="scenario:$scenario"
        fi
        if [[ "$relaunch_policy" != "$expected_relaunch_policy" ]]; then
            printf 'RED: scenario does not match the prepared acceptance run\n' >&2
            exit 1
        fi
        if [[ "$scenario" != permission-* ]] && [[ "$app_pid" != "$original_pid" ]]; then
            printf 'RED: scenario process died and was replaced (original=%s current=%s)\n' "$original_pid" "$app_pid" >&2
            exit 1
        fi
        jq -e --arg run_id "$session_run_id" --argjson process_id "$app_pid" '
            .acceptance_run_id == $run_id and .process_id == $process_id
        ' "$evidence_file" >/dev/null
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
                .permission_preflight_granted == false and
                .permission_request_attempted == true and
                .permission_request_granted == false and
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
            case "$scenario" in
                permission-not-determined|permission-denied)
                    write_tcc_state denied "$session_run_id"
                    ;;
                permission-revoked)
                    write_tcc_state revoked "$session_run_id"
                    ;;
            esac
            relaunched="no"
            [[ "$app_pid" != "$original_pid" ]] && relaunched="yes"
            printf 'TICKET01_SCENARIO_OK scenario=%s pid=%s relaunched=%s recent_history=0 submits=0 explanation=yes redacted=yes\n' "$scenario" "$app_pid" "$relaunched"
        else
            printf 'TICKET01_SCENARIO_OK scenario=%s pid=%s recent_history=0 submits=0 recovery_overlay=yes redacted=yes\n' "$scenario" "$app_pid"
        fi
        ;;
    stop)
        app_pid=""
        if [[ -r "$session_file" ]] && [[ -f "$evidence_file" ]]; then
            load_session_state
            candidate_pid="$(find_app_pid || true)"
            if [[ -n "$candidate_pid" ]] && jq -e --arg run_id "$session_run_id" --argjson process_id "$candidate_pid" '
                .acceptance_run_id == $run_id and .process_id == $process_id
            ' "$evidence_file" >/dev/null; then
                app_pid="$candidate_pid"
            fi
        fi
        if [[ -n "$app_pid" ]]; then
            kill "$app_pid"
            while kill -0 "$app_pid" >/dev/null 2>&1; do sleep 0.1; done
        fi
        rm -f "$relaunch_marker" "$session_file"
        printf 'TICKET01_ACCEPTANCE_STOPPED\n'
        ;;
    *)
        printf 'Usage: %s [launch|verify|launch-secondary|verify-secondary|prepare-permission-not-determined|prepare-permission-revoked|launch-scenario NAME|verify-scenario NAME|stop]\n' "$0" >&2
        exit 2
        ;;
esac
