#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Griddle.app"
DEST="/Applications/$APP_NAME"

# Determine source: local build or downloaded release
if [ -n "${1:-}" ]; then
    SRC="$1"
elif [ -d ".build/$APP_NAME" ]; then
    SRC=".build/$APP_NAME"
else
    echo "Usage: $0 [path/to/Griddle.app]"
    echo ""
    echo "If no path is given, installs from .build/$APP_NAME (run ./build.sh first)."
    exit 1
fi

if [ ! -d "$SRC" ]; then
    echo "Error: $SRC not found."
    exit 1
fi

# Quit Griddle if running
if pgrep -x Griddle >/dev/null 2>&1; then
    echo "Stopping running Griddle..."
    killall Griddle
    sleep 1
fi

echo "Installing $SRC -> $DEST"
rm -rf "$DEST"
cp -r "$SRC" "$DEST"

# Remove quarantine flag (needed for downloaded releases)
xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true

echo "Installed. Note: if this is a new install location, macOS will"
echo "require you to re-grant Accessibility permission."
echo ""
echo "To launch: open $DEST"
