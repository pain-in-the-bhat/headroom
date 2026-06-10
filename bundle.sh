#!/bin/bash

# Build headroom.app from SPM project.
# Run: ./bundle.sh

set -e

cd "$(dirname "$0")"
APP_NAME="headroom"
BUNDLE_DIR="build/$APP_NAME.app"
EXECUTABLE="headroom"

echo "▸ Building release binary..."
swift build -c release

echo "▸ Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
cp .build/release/$EXECUTABLE "$BUNDLE_DIR/Contents/MacOS/$EXECUTABLE"

# Copy Info.plist
cp Resources/Info.plist "$BUNDLE_DIR/Contents/Info.plist"

# Copy entitlements (used for signing)
cp headroom.entitlements "$BUNDLE_DIR/Contents/Resources/"

# Ad-hoc sign
echo "▸ Signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements headroom.entitlements \
    "$BUNDLE_DIR"

echo ""
echo "✓ Done: $BUNDLE_DIR"
echo "  Run: open build/"
