#!/bin/bash
# Cut a new release: bump version, build, zip, and publish to GitHub.
#   ./release.sh v1.1
set -euo pipefail
cd "$(dirname "$0")"

if [ $# -lt 1 ]; then
    echo "Usage: ./release.sh <version>    e.g. ./release.sh v1.1"
    exit 1
fi

RAW="$1"
VERSION="${RAW#v}"          # 1.1
TAG="v${VERSION}"           # v1.1
APP_NAME="Icon Composter"
ZIP="dist/Icon-Composter.zip"

if gh release view "$TAG" >/dev/null 2>&1; then
    echo "✗ Release $TAG already exists. Pick a new version."
    exit 1
fi

echo "› Releasing $TAG …"

# 1. Stamp the version into the bundle.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Info.plist

# 2. Commit whatever's staged for this release + push, so the tag matches the code.
git add -A
git commit -q -m "Release $TAG" || echo "  (nothing new to commit)"
git push -q origin main

# 3. Build + zip.
./build.sh
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent "build/$APP_NAME.app" "$ZIP"

# 4. Publish the GitHub release with the zip attached.
gh release create "$TAG" "$ZIP" \
    --title "$APP_NAME $VERSION" \
    --notes "$(cat <<EOF
A tiny macOS Tahoe app to live-test Icon Composer \`.icon\` files in the Dock.

## Install
1. Download **Icon-Composter.zip**, unzip it.
2. Move **Icon Composter.app** to \`~/Applications\` or your Desktop (a writable spot — not a read-only DMG or locked /Applications).
3. **Right-click the app → Open → Open** (one-time Gatekeeper bypass for this ad-hoc build).
4. Drop a \`.icon\` onto the window or the Dock icon.

## Requirements
- macOS 26 (Tahoe)+
- Xcode installed (the app uses \`actool\`/\`codesign\` — you already have it if you make \`.icon\` files).
EOF
)"

echo ""
echo "✓ Released $TAG"
echo "  ⬇️  https://github.com/dmtr-shvydkyi/icon-composter/releases/latest/download/Icon-Composter.zip"
