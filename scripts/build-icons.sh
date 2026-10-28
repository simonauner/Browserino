#!/bin/sh
# Regenerates Lotsen/Lotsen.icns and the README logo from images/icon/AppIcon.svg.
set -eu
cd "$(dirname "$0")/.."

ICONSET="$(mktemp -d)/Lotsen.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    swift scripts/render-svg.swift images/icon/AppIcon.svg "$ICONSET/icon_${size}x${size}.png" "$size"
    swift scripts/render-svg.swift images/icon/AppIcon.svg "$ICONSET/icon_${size}x${size}@2x.png" "$((size * 2))"
done
iconutil -c icns -o Lotsen/Lotsen.icns "$ICONSET"
swift scripts/render-svg.swift images/icon/AppIcon.svg images/lotsen.png 256
rm -rf "$(dirname "$ICONSET")"
echo "Updated Lotsen/Lotsen.icns and images/lotsen.png"
