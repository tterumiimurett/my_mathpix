#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
cd "$repo_dir"

sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ ! -d "$sdk_path" ]]; then
    sdk_path="$(xcrun --show-sdk-path)"
fi
mkdir -p .build/cache .build/config .build/security .build/module-cache
export SDKROOT="$sdk_path"
export CLANG_MODULE_CACHE_PATH="$repo_dir/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$repo_dir/.build/module-cache"
swift_args=(
    --disable-sandbox
    --sdk "$sdk_path"
    --cache-path .build/cache
    --config-path .build/config
    --security-path .build/security
    --manifest-cache local
)

swift build -c release "${swift_args[@]}"

build_dir="$(swift build -c release --show-bin-path "${swift_args[@]}")"
app_name="${MYMATHPIX_APP_NAME:-MyMathpix}"
bundle_id="${MYMATHPIX_BUNDLE_ID:-}"
app_dir="$repo_dir/dist/$app_name.app"
contents_dir="$app_dir/Contents"

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"

cp "$build_dir/MyMathpix" "$contents_dir/MacOS/MyMathpix"
cp "$repo_dir/Config/Info.plist" "$contents_dir/Info.plist"
if [[ -n "$bundle_id" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$contents_dir/Info.plist"
fi
if [[ "$app_name" != "MyMathpix" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $app_name" "$contents_dir/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $app_name" "$contents_dir/Info.plist"
fi

resource_bundle="$build_dir/MyMathpix_MyMathpix.bundle"
resource_root="$resource_bundle/Resources"
required_resources=(
    "$resource_root/katex.min.css"
    "$resource_root/katex.min.js"
    "$resource_root/KATEX-LICENSE.txt"
    "$resource_root/fonts/KaTeX_Main-Regular.woff2"
)
if [[ ! -d "$resource_bundle" ]]; then
    printf 'Required SwiftPM resource bundle is missing: %s\n' "$resource_bundle" >&2
    exit 1
fi
for resource in "${required_resources[@]}"; do
    if [[ ! -s "$resource" ]]; then
        printf 'Required preview resource is missing or empty: %s\n' "$resource" >&2
        exit 1
    fi
done
cp -R "$resource_bundle" "$contents_dir/Resources/"

codesign --force --deep --sign - \
    --entitlements "$repo_dir/Config/MyMathpix.entitlements" \
    "$app_dir"

echo "$app_dir"
