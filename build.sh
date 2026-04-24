#!/usr/bin/env bash
# Build Amnezia Cloak.app + Amnezia-Cloak.dmg from SPM sources.
# Outputs: build/Amnezia Cloak.app and Amnezia-Cloak.dmg at repo root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Amnezia Cloak.app"
DMG="$ROOT/Amnezia-Cloak.dmg"

rm -rf "$BUILD" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1. Compile the executable with SPM.
cd "$ROOT"
swift build -c release --product AmneziaCloak

# 2. Assemble the .app bundle.
cp "$ROOT/.build/release/AmneziaCloak"      "$APP/Contents/MacOS/AmneziaCloak"
cp "$ROOT/Info.plist"                       "$APP/Contents/Info.plist"
cp "$ROOT/assets/app-icon.icns"             "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/assets/menubar-icon.png"          "$APP/Contents/Resources/menubar-icon.png"
cp "$ROOT/assets/menubar-icon@2x.png"       "$APP/Contents/Resources/menubar-icon@2x.png"
cp "$ROOT/assets/menubar-icon@3x.png"       "$APP/Contents/Resources/menubar-icon@3x.png"

# 3. Ad-hoc sign so Gatekeeper allows unsigned local launch after DMG copy.
#    No nested content, so --deep is unnecessary (and deprecated since macOS 11).
codesign --force --sign - "$APP"

# 4. DMG with drag-to-Applications UX.
STAGE="$BUILD/dmg-stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
    -volname "Amnezia Cloak" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null

echo "built: $APP"
echo "dmg  : $DMG"
