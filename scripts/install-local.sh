#!/bin/sh
# Builds Lotsen, ad-hoc signs it and installs it to /Applications for local development.
set -eu
cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-/Applications/Lotsen.app}"
DERIVED_DATA="build/DerivedData"
APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Lotsen.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# xcode-select may point at the Command Line Tools, which cannot build apps.
if [ -z "${DEVELOPER_DIR:-}" ] && ! xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mkdir -p build
echo "Building $CONFIGURATION..."
if ! xcodebuild -project Lotsen.xcodeproj -scheme Lotsen -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build >build/xcodebuild.log 2>&1; then
    grep -E ' error:' build/xcodebuild.log || tail -20 build/xcodebuild.log
    echo "Build failed, see build/xcodebuild.log" >&2
    exit 1
fi

# Ad-hoc sign so the hardened runtime keeps the Apple Events entitlement used for tab transfer.
find "$APP/Contents" \( -name '*.framework' -o -name '*.dylib' \) -prune -exec codesign --force --sign - --options runtime {} \;
codesign --force --sign - --options runtime --entitlements Lotsen/Lotsen.entitlements "$APP"
codesign --verify --deep --strict "$APP"

if pgrep -x Lotsen >/dev/null; then
    echo "Stopping running Lotsen..."
    pkill -x Lotsen || true
    while pgrep -x Lotsen >/dev/null; do sleep 0.2; done
fi

echo "Installing to $DESTINATION..."
rm -rf "$DESTINATION"
ditto "$APP" "$DESTINATION"

# Keep LaunchServices from routing links to the copy in build/.
"$LSREGISTER" -u "$PWD/$APP" >/dev/null 2>&1 || true
"$LSREGISTER" -f "$DESTINATION"

open "$DESTINATION"
if [ -d /Applications/Browserino.app ]; then
    echo "Browserino.app is still installed. Lotsen copied its settings on first launch; uninstall Browserino so the two don't compete as the default browser."
fi
echo "Installed $(defaults read "$DESTINATION/Contents/Info" CFBundleShortVersionString) from $(git rev-parse --short HEAD)"
