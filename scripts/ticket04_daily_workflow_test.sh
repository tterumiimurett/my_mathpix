#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/MyMathpix.app"
app_binary="$app_dir/Contents/MacOS/MyMathpix"
info_plist="$app_dir/Contents/Info.plist"
license_file="$app_dir/Contents/Resources/MyMathpix_MyMathpix.bundle/Resources/KATEX-LICENSE.txt"
output_file="$(mktemp /private/tmp/mymathpix-ticket04-workflow.XXXXXX)"
trap 'rm -f "$output_file"' EXIT

"$repo_dir/scripts/build_app.sh" >/dev/null
codesign --verify --deep --strict "$app_dir"

entitlements="$(codesign -d --entitlements :- "$app_dir" 2>/dev/null)"
if [[ "$entitlements" != *"com.apple.security.app-sandbox"* ]]; then
    printf 'RED: App Sandbox entitlement is missing\n' >&2
    exit 1
fi
if [[ "$entitlements" != *"com.apple.security.files.user-selected.read-write"* ]]; then
    printf 'RED: deliberate diagnostic export entitlement is missing\n' >&2
    exit 1
fi

version="$(plutil -extract CFBundleShortVersionString raw "$info_plist")"
build="$(plutil -extract CFBundleVersion raw "$info_plist")"
if [[ -z "$version" || -z "$build" || ! -s "$license_file" ]]; then
    printf 'RED: version or bundled third-party license is missing\n' >&2
    exit 1
fi

set +e
"$app_binary" --ticket04-daily-workflow-self-test >"$output_file" 2>&1
exit_status=$?
set -e
if [[ "$exit_status" -ne 0 ]] || ! grep -Fxq 'TICKET04_DAILY_WORKFLOW_OK' "$output_file"; then
    grep -E '^(TICKET04_|Ticket 04|- )' "$output_file" || true
    printf 'RED: signed App daily-workflow contract failed (status=%s)\n' "$exit_status" >&2
    exit 1
fi

required_shell_labels=(
    'Capture Snippet'
    'MenuBarContent'
    'ContentView'
    'SettingsView'
    'Clear Recent History'
    'Export Diagnostics'
    ' License Notice'
)
binary_strings="$(strings "$app_binary")"
for label in "${required_shell_labels[@]}"; do
    if [[ "$binary_strings" != *"$label"* ]]; then
        printf 'RED: signed App is missing shell label: %s\n' "$label" >&2
        exit 1
    fi
done

printf 'TICKET04_SIGNED_DAILY_WORKFLOW_OK history=create-edit-failed-retry-relaunch-delete-clear-evict-image-delete diagnostics=fixed-codes-redacted-manual-export shell=menu-bar-and-window shortcut=control-command-m-conflict-visible launch-at-login=opt-in version=%s licenses=bundled\n' "$version"
