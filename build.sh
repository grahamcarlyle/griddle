#!/usr/bin/env bash
set -euo pipefail

# Build Griddle in release mode and package as .app bundle
cd "$(dirname "$0")"
swift build -c release

APP_DIR=".build/Griddle.app/Contents"
mkdir -p "$APP_DIR/MacOS"

cp .build/release/Griddle "$APP_DIR/MacOS/Griddle"

cat > "$APP_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.grahamcarlyle.griddle</string>
    <key>CFBundleName</key>
    <string>Griddle</string>
    <key>CFBundleExecutable</key>
    <string>Griddle</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign after all bundle contents are in place
codesign --force --sign - .build/Griddle.app

echo ""
echo "Build complete: .build/Griddle.app"
echo ""
echo "To run:    open .build/Griddle.app"
echo "To install: cp -r .build/Griddle.app /Applications/"
