#!/bin/bash
# Builds Icon Composter.app — a tiny macOS Tahoe app for live-testing app icons.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Icon Composter"
BIN_NAME="IconComposter"
BUNDLE="build/${APP_NAME}.app"
TARGET="arm64-apple-macos26.0"

echo "› Compiling…"
rm -rf build
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

swiftc -O \
    -target "$TARGET" \
    -framework AppKit \
    -framework SwiftUI \
    -framework QuickLookThumbnailing \
    -framework UniformTypeIdentifiers \
    Sources/*.swift \
    -o "$BUNDLE/Contents/MacOS/${BIN_NAME}"

cp Info.plist "$BUNDLE/Contents/Info.plist"

echo "› Compiling default app icon…"
WORK=$(mktemp -d); mkdir -p "$WORK/out"
cp -R "Resources/DefaultAppIcon.icon" "$WORK/AppIcon.icon"
xcrun actool --compile "$WORK/out" \
    --app-icon AppIcon \
    --platform macosx --minimum-deployment-target 26.0 \
    --output-partial-info-plist "$WORK/p.plist" \
    "$WORK/AppIcon.icon" >/dev/null
cp "$WORK/out/Assets.car"  "$BUNDLE/Contents/Resources/Assets.car"
cp "$WORK/out/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
# Stash a pristine copy so "Reset to Default" can restore this icon.
mkdir -p "$BUNDLE/Contents/Resources/Default"
cp "$WORK/out/Assets.car"  "$BUNDLE/Contents/Resources/Default/Assets.car"
cp "$WORK/out/AppIcon.icns" "$BUNDLE/Contents/Resources/Default/AppIcon.icns"
rm -rf "$WORK"

# Ad-hoc sign so QuickLook / Dock are happy with an unsigned local build.
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "✓ Built $BUNDLE"
