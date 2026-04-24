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
cp "$ROOT/scripts/awg-helper"               "$APP/Contents/Resources/awg-helper"
cp "$ROOT/scripts/install-helper.sh"        "$APP/Contents/Resources/install-helper.sh"
chmod +x "$APP/Contents/Resources/awg-helper" "$APP/Contents/Resources/install-helper.sh"

# Bundle prebuilt CLI binaries if release-workflow produced them. On local
# dev builds this directory is empty and the first-run installer will point
# the user at upstream install links.
if [ -d "$ROOT/scripts/bin" ] && compgen -G "$ROOT/scripts/bin/*" > /dev/null; then
    mkdir -p "$APP/Contents/Resources/bin"
    cp "$ROOT/scripts/bin/"* "$APP/Contents/Resources/bin/"
    chmod +x "$APP/Contents/Resources/bin/"*
    echo "bundled binaries:"
    ls -la "$APP/Contents/Resources/bin/"
fi

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
