#!/bin/bash
# Setup script: downloads OSM data, fonts, and builds MBTiles.
# Run with output volumes mounted:
#   docker run --rm \
#     -v $(pwd)/data:/app/data \
#     -v $(pwd)/tiles:/app/tiles \
#     -v $(pwd)/styles:/app/styles \
#     gyeme-maps-setup

set -e

SCRIPT_DIR="/app/scripts"
DATA_DIR="/app/data"
TILES_DIR="/app/tiles"
STYLES_DIR="/app/styles"

mkdir -p "$DATA_DIR" "$TILES_DIR" "$STYLES_DIR"

# ── Step 1: Download Ghana OSM data ──────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Step 1/3 — Downloading OSM data     ║"
echo "╚══════════════════════════════════════╝"

GHANA_PBF="$DATA_DIR/ghana-latest.osm.pbf"
GHANA_PBF_URL="https://download.geofabrik.de/africa/ghana-latest.osm.pbf"

if [ -f "$GHANA_PBF" ]; then
    echo "Ghana OSM data already exists, checking for updates..."
    curl -z "$GHANA_PBF" -L -o "$GHANA_PBF" "$GHANA_PBF_URL"
else
    echo "Downloading Ghana OSM data (~80MB)..."
    curl -L -o "$GHANA_PBF" "$GHANA_PBF_URL"
fi

echo "Done. Size: $(du -h "$GHANA_PBF" | cut -f1)"

# ── Step 2: Download fonts ────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Step 2/3 — Downloading fonts        ║"
echo "╚══════════════════════════════════════╝"

FONTS_DIR="$STYLES_DIR/fonts"
mkdir -p "$FONTS_DIR"

if [ -d "$FONTS_DIR" ] && [ "$(ls -A "$FONTS_DIR" 2>/dev/null)" ]; then
    echo "Fonts already present in $FONTS_DIR, skipping."
else
    echo "Downloading OpenMapTiles fonts..."
    curl -L -o /tmp/fonts.zip "https://github.com/openmaptiles/fonts/releases/download/v2.0/v2.0.zip"
    echo "Extracting fonts..."
    unzip -o /tmp/fonts.zip -d "$FONTS_DIR"
    rm /tmp/fonts.zip
    echo "Fonts installed to $FONTS_DIR"
fi

# ── Step 3: Generate MBTiles with tilemaker ───────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  Step 3/3 — Building MBTiles         ║"
echo "╚══════════════════════════════════════╝"

OUTPUT_MBTILES="$TILES_DIR/ghana.mbtiles"
STORE_DIR="/tmp/tilemaker-store"
mkdir -p "$STORE_DIR"

echo "Input:  $GHANA_PBF"
echo "Output: $OUTPUT_MBTILES"
echo "This may take 10–30 minutes..."
echo ""

rm -f "$OUTPUT_MBTILES"

tilemaker \
    --input "$GHANA_PBF" \
    --output "$OUTPUT_MBTILES" \
    --config "$SCRIPT_DIR/tilemaker/config.json" \
    --process "$SCRIPT_DIR/tilemaker/process.lua" \
    --store "$STORE_DIR"

rm -rf "$STORE_DIR"

echo ""
echo "MBTiles done. Size: $(du -h "$OUTPUT_MBTILES" | cut -f1)"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  All steps complete!                  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Generated files:"
echo "  $OUTPUT_MBTILES"
echo "  $FONTS_DIR"
