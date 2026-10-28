#!/bin/sh
# Builds Browserino, ad-hoc signs it and installs it to /Applications for local development.
set -eu
cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-/Applications/Browserino.app}"
DERIVED_DATA="build/DerivedData"
APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Browserino.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# xcode-select may point at the Command Line Tools, which cannot build apps.
if [ -z "${DEVELOPER_DIR:-}" ] && ! xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mkdir -p build
echo "Building $CONFIGURATION..."
if ! xcodebuild -project Browserino.xcodeproj -scheme Browserino -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build >build/xcodebuild.log 2>&1; then
    grep -E ' error:' build/xcodebuild.log || tail -20 build/xcodebuild.log
    echo "Build failed, see build/xcodebuild.log" >&2
    exit 1
fi

# Ad-hoc sign so the hardened runtime keeps the Apple Events entitlement used for tab transfer.
find "$APP/Contents" \( -name '*.framework' -o -name '*.dylib' \) -prune -exec codesign --force --sign - --options runtime {} \;
codesign --force --sign - --options runtime --entitlements Browserino/Browserino.entitlements "$APP"
codesign --verify --deep --strict "$APP"

if pgrep -x Browserino >/dev/null; then
    echo "Stopping running Browserino..."
    pkill -x Browserino || true
    while pgrep -x Browserino >/dev/null; do sleep 0.2; done
fi

echo "Installing to $DESTINATION..."
rm -rf "$DESTINATION"
ditto "$APP" "$DESTINATION"

# Keep LaunchServices from routing links to the copy in build/.
"$LSREGISTER" -u "$PWD/$APP" >/dev/null 2>&1 || true
"$LSREGISTER" -f "$DESTINATION"

open "$DESTINATION"
echo "Installed $(defaults read "$DESTINATION/Contents/Info" CFBundleShortVersionString) from $(git rev-parse --short HEAD)"
