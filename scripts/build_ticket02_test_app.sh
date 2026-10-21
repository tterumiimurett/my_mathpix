#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/my_mathpix_ticket2.app"
if [[ -e "$app_dir" ]]; then
    print -u2 'The Ticket 02 test bundle already exists; preserve or move it before rebuilding.'
    exit 1
fi
zsh "$repo_dir/scripts/build_app.sh"
ditto "$repo_dir/dist/MyMathpix.app" "$app_dir"
mv "$app_dir/Contents/MacOS/MyMathpix" "$app_dir/Contents/MacOS/my_mathpix_ticket2"
plist="$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName my_mathpix_ticket2' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName my_mathpix_ticket2' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable my_mathpix_ticket2' "$plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.byterumi.mymathpix.ticket2' "$plist"
codesign --force --deep --sign - --entitlements "$repo_dir/Config/MyMathpix.entitlements" "$app_dir"
codesign --verify --deep --strict "$app_dir"
print "$app_dir"
