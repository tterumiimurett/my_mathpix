#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
icon_dir="$(mktemp -d "${TMPDIR:-/tmp}/mymathpix-icon.XXXXXX")"
trap 'rm -rf "$icon_dir"' EXIT
mkdir "$icon_dir/AppIcon.iconset"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$repo_dir/Config/AppIcon.png" \
        --out "$icon_dir/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$repo_dir/Config/AppIcon.png" \
        --out "$icon_dir/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_dir/AppIcon.iconset" -o "$repo_dir/Config/AppIcon.icns"
