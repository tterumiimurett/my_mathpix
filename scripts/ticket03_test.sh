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

swift run MyMathpix \
    --disable-sandbox \
    --sdk "$sdk_path" \
    --cache-path .build/cache \
    --config-path .build/config \
    --security-path .build/security \
    --manifest-cache local \
    --ticket03-self-test
