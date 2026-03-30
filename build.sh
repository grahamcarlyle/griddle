#!/usr/bin/env bash
set -euo pipefail

# Build Griddle in release mode
cd "$(dirname "$0")"
swift build -c release

echo ""
echo "Build complete: .build/release/Griddle"
echo ""
echo "To run: .build/release/Griddle"
echo "To install: cp .build/release/Griddle /usr/local/bin/griddle"
