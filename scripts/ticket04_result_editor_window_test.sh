#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
"$repo_dir/scripts/build_app.sh" >/dev/null
test_dir="$(mktemp -d /private/tmp/mymathpix-ticket04-window.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
app_dir="$test_dir/MyMathpix.app"
ditto "$repo_dir/dist/MyMathpix.app" "$app_dir"
# Keep the normal installation's history, credentials and saved window state out
# of this test. Only the capture output and recognition service are synthetic.
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.byterumi.mymathpix.ticket04windowtest' "$app_dir/Contents/Info.plist"
codesign --force --deep --sign - --entitlements "$repo_dir/Config/MyMathpix.entitlements" "$app_dir"
codesign --verify --deep --strict "$app_dir"
output_file="$test_dir/output.txt"
set +e
"$app_dir/Contents/MacOS/MyMathpix" --ticket04-result-editor-window-self-test >"$output_file" 2>&1
exit_status=$?
set -e
sed -n '/^TICKET04_/p' "$output_file"
if [[ "$exit_status" -ne 0 ]] || ! grep -Fxq 'TICKET04_RESULT_EDITOR_WINDOW_OK all-connected-displays' "$output_file"; then
    printf 'RED: signed Result Editor window acceptance failed (status=%s)\n' "$exit_status" >&2
    exit 1
fi
