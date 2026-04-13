#!/usr/bin/env bash
set -euo pipefail

# Build Griddle in release mode and package as .app bundle
cd "$(dirname "$0")"
swift build -c release

APP_DIR=".build/Griddle.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

cp .build/release/Griddle "$APP_DIR/MacOS/Griddle"
cp Griddle.icns "$APP_DIR/Resources/Griddle.icns"

BUNDLE_NAME="Griddle"
VERSION_KEYS=""
if [ -n "${GRIDDLE_VERSION:-}" ]; then
    BUNDLE_NAME="Griddle (build $GRIDDLE_VERSION)"
    VERSION_KEYS="    <key>CFBundleShortVersionString</key>
    <string>$GRIDDLE_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$GRIDDLE_VERSION</string>"
fi

cat > "$APP_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.grahamcarlyle.griddle</string>
    <key>CFBundleName</key>
    <string>$BUNDLE_NAME</string>
    <key>CFBundleExecutable</key>
    <string>Griddle</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>Griddle</string>
    <key>LSUIElement</key>
    <true/>
$VERSION_KEYS
</dict>
</plist>
EOF

# Prefer a stable self-signed identity so macOS keeps the Accessibility
# grant across rebuilds; fall back to ad-hoc if not configured (e.g. CI).
SIGN_IDENTITY="${GRIDDLE_SIGN_IDENTITY:-Griddle Dev}"
if security find-identity -v -p codesigning | grep -q "\"$SIGN_IDENTITY\""; then
    echo "Signing with identity: $SIGN_IDENTITY"
    codesign --force --sign "$SIGN_IDENTITY" .build/Griddle.app
else
    echo "Identity '$SIGN_IDENTITY' not found in keychain; using ad-hoc signing."
    echo "Tip: create a self-signed Code Signing certificate named '$SIGN_IDENTITY'"
    echo "     in Keychain Access to preserve Accessibility permission across rebuilds."
    echo "     See the 'Building from source' section in README.md."
    codesign --force --sign - .build/Griddle.app
fi

echo ""
echo "Build complete: .build/Griddle.app"
echo ""
echo "To run:    open .build/Griddle.app"
echo "To install: cp -r .build/Griddle.app /Applications/"
