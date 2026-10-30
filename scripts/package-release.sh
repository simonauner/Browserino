#!/bin/bash
# Builds the universal, ad hoc signed Homebrew download without Apple credentials.
set -euo pipefail
cd "$(dirname "$0")/.."

app="$PWD/build/Release/Lotsen.app"
archive="$PWD/build/Lotsen.zip"

xcodebuild -project Lotsen.xcodeproj -scheme Lotsen -configuration Release \
    -derivedDataPath build/ReleaseDerivedData \
    -destination 'generic/platform=macOS' ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO build
mkdir -p "$(dirname "$app")"
rm -rf "$app"
ditto build/ReleaseDerivedData/Build/Products/Release/Lotsen.app "$app"
lipo "$app/Contents/MacOS/Lotsen" -verify_arch arm64
lipo "$app/Contents/MacOS/Lotsen" -verify_arch x86_64

# Sign nested code before the app so the outer signature seals the signed contents.
find "$app/Contents" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0 |
    while IFS= read -r -d '' nested; do
        codesign --force --sign - --options runtime "$nested"
    done
codesign --force --sign - --options runtime --entitlements Lotsen/Lotsen.entitlements "$app"
codesign --verify --deep --strict "$app"

rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
