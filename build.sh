#!/usr/bin/env bash
# Build Amnezia Cloak.app + Amnezia-Cloak.dmg from sources in this directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Amnezia Cloak.app"
DMG="$ROOT/Amnezia-Cloak.dmg"

rm -rf "$BUILD" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$ROOT/Info.plist"            "$APP/Contents/Info.plist"
cp "$ROOT/AppIcon.icns"          "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/MenubarIcon.png"       "$APP/Contents/Resources/MenubarIcon.png"
cp "$ROOT/MenubarIcon@2x.png"    "$APP/Contents/Resources/MenubarIcon@2x.png"
cp "$ROOT/MenubarIcon@3x.png"    "$APP/Contents/Resources/MenubarIcon@3x.png"

swiftc "$ROOT/main.swift" -O -o "$APP/Contents/MacOS/AmneziaCloak"

# ad-hoc sign so Gatekeeper allows unsigned local launch after dragging from DMG.
# No nested content → --deep is unnecessary (and deprecated since macOS 11).
codesign --force --sign - "$APP"

# DMG with drag-to-Applications UX
STAGE="$BUILD/dmg-stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Amnezia Cloak" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "built: $APP"
echo "dmg  : $DMG"
