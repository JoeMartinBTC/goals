#!/usr/bin/env bash
# Goals — Release-Build, .app-Bundle, Installation nach /Applications, Start.
# Aufruf: bash Scripts/build_local_app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Goals"
BUNDLE_ID="com.joemartinbtc.Goals"
VERSION="1.0.0"
BUILD_DIR="build"
APP_OUT="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_OUT/Contents"

echo "── 1/5  Release-Build"
swift build -c release
BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "── 2/5  Symbol"
mkdir -p "$BUILD_DIR"
[[ -f "$BUILD_DIR/AppIcon.icns" ]] || swift Scripts/generate_icon.swift

echo "── 3/5  Bundle"
rm -rf "$APP_OUT"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BINARY" "$CONTENTS/MacOS/$APP_NAME"
cp "$BUILD_DIR/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict>
</plist>
EOF
printf "APPL????" > "$CONTENTS/PkgInfo"

echo "── 4/5  Ad-hoc-Signatur"
codesign --force --sign - --timestamp=none "$APP_OUT"

echo "── 5/5  Installation"
pkill -f "/Applications/$APP_NAME.app" 2>/dev/null || true
rsync -a --delete "$APP_OUT/" "/Applications/$APP_NAME.app/"
codesign --force --sign - --timestamp=none "/Applications/$APP_NAME.app"
open "/Applications/$APP_NAME.app"
echo "✓ /Applications/$APP_NAME.app läuft"
