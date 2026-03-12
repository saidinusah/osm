#!/bin/bash

# Generate MBTiles from Ghana OSM data using OpenMapTiles
# This creates vector tiles for TileServer GL

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
TILES_DIR="$PROJECT_DIR/tiles"

GHANA_PBF="$DATA_DIR/ghana-latest.osm.pbf"
OUTPUT_MBTILES="$TILES_DIR/ghana.mbtiles"

if [ ! -f "$GHANA_PBF" ]; then
    echo "Error: Ghana OSM data not found at $GHANA_PBF"
    echo "Run ./scripts/download-ghana-data.sh first"
    exit 1
fi

mkdir -p "$TILES_DIR"

echo "=== Generating Vector Tiles for Ghana ==="
echo "Input: $GHANA_PBF"
echo "Output: $OUTPUT_MBTILES"
echo ""

# Use tilemaker to generate MBTiles (simpler than full OpenMapTiles pipeline)
# tilemaker is a fast, single-binary tile generator

echo "Pulling tilemaker Docker image..."
docker pull ghcr.io/systemed/tilemaker:master

echo ""
echo "Generating MBTiles (this may take 10-30 minutes for Ghana)..."
echo "(Note: On Apple Silicon, this runs via Rosetta emulation - performance is slightly slower)"

# Remove existing mbtiles to avoid issues
rm -f "$OUTPUT_MBTILES"

# Create temp directory for tilemaker's on-disk store (reduces RAM usage)
STORE_DIR="$PROJECT_DIR/.tilemaker-tmp"
mkdir -p "$STORE_DIR"

docker run --rm \
    -v "$DATA_DIR:/data" \
    -v "$TILES_DIR:/output" \
    -v "$SCRIPT_DIR/tilemaker:/config" \
    -v "$STORE_DIR:/store" \
    ghcr.io/systemed/tilemaker:master \
    --input /data/ghana-latest.osm.pbf \
    --output /output/ghana.mbtiles \
    --config /config/config.json \
    --process /config/process.lua \
    --store /store

# Clean up temp store
rm -rf "$STORE_DIR"

echo ""
echo "MBTiles generation complete!"
echo "File size: $(du -h "$OUTPUT_MBTILES" | cut -f1)"
echo ""
echo "The tiles are ready for TileServer GL."
