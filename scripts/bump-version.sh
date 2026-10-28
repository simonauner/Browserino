#!/bin/sh
# Bumps Lotsen's version following semantic versioning.
#
#   scripts/bump-version.sh major|minor|patch
#   scripts/bump-version.sh 1.2.3
#
# Sets MARKETING_VERSION in every build configuration and increments
# CURRENT_PROJECT_VERSION, so each release also gets a new build number.
set -eu

PROJECT="$(dirname "$0")/../Lotsen.xcodeproj/project.pbxproj"

usage() {
    echo "usage: $0 major|minor|patch|X.Y.Z" >&2
    exit 64
}

[ $# -eq 1 ] || usage

current=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);/\1/p' "$PROJECT" | sort -u)
if [ "$(printf '%s\n' "$current" | wc -l | tr -d ' ')" != 1 ]; then
    echo "MARKETING_VERSION differs between build configurations: $current" >&2
    exit 1
fi

IFS=. read -r major minor patch <<EOF
$current
EOF

case "$1" in
    major) next="$((major + 1)).0.0" ;;
    minor) next="$major.$((minor + 1)).0" ;;
    patch) next="$major.$minor.$((patch + 1))" ;;
    *.*.*)
        printf '%s\n' "$1" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' || usage
        next="$1"
        ;;
    *) usage ;;
esac

build=$(sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/p' "$PROJECT" | sort -n | tail -1)
next_build=$((build + 1))

sed -i '' \
    -e "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $next;/" \
    -e "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $next_build;/" \
    "$PROJECT"

echo "$current -> $next (build $next_build)"
