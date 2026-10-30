#!/bin/bash
# Builds the universal, Developer ID signed and notarized Homebrew download.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGNING_IDENTITY:?Set the Developer ID Application certificate identity}"
: "${SIGNING_KEYCHAIN:?Set the keychain containing its private key}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set a notarytool credential profile}"

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
        codesign --force --sign "$SIGNING_IDENTITY" --keychain "$SIGNING_KEYCHAIN" \
            --options runtime --timestamp "$nested"
    done
codesign --force --sign "$SIGNING_IDENTITY" --keychain "$SIGNING_KEYCHAIN" \
    --options runtime --timestamp --entitlements Lotsen/Lotsen.entitlements "$app"
codesign --verify --deep --strict "$app"

rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --keychain "$SIGNING_KEYCHAIN" --wait --timeout 30m
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose "$app"

# The distributed ZIP must contain the stapled app, not the submitted copy.
rm "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
