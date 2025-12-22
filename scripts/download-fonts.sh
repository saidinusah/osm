#!/bin/bash

# Download fonts for TileServer GL

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FONTS_DIR="$PROJECT_DIR/styles/fonts"

mkdir -p "$FONTS_DIR"

echo "=== Downloading Map Fonts ==="

# Download Noto Sans fonts from OpenMapTiles
FONT_URL="https://github.com/openmaptiles/fonts/releases/download/v2.0/v2.0.zip"

echo "Downloading fonts from OpenMapTiles..."
curl -L -o /tmp/fonts.zip "$FONT_URL"

echo "Extracting fonts..."
unzip -o /tmp/fonts.zip -d "$FONTS_DIR"

# Clean up
rm /tmp/fonts.zip

echo ""
echo "Fonts installed to $FONTS_DIR"
ls -la "$FONTS_DIR"
