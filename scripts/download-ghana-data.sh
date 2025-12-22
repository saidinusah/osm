#!/bin/bash

# Download Ghana OSM data from Geofabrik
# This script downloads the latest Ghana OSM extract

set -e

DATA_DIR="$(dirname "$0")/../data"
mkdir -p "$DATA_DIR"

GHANA_PBF_URL="https://download.geofabrik.de/africa/ghana-latest.osm.pbf"
GHANA_PBF="$DATA_DIR/ghana-latest.osm.pbf"

echo "=== Downloading Ghana OSM Data ==="
echo "Source: $GHANA_PBF_URL"
echo "Destination: $GHANA_PBF"

if [ -f "$GHANA_PBF" ]; then
    echo "Ghana OSM data already exists. Checking for updates..."
    # Download only if remote is newer
    curl -z "$GHANA_PBF" -L -o "$GHANA_PBF" "$GHANA_PBF_URL"
else
    echo "Downloading Ghana OSM data (this may take a few minutes)..."
    curl -L -o "$GHANA_PBF" "$GHANA_PBF_URL"
fi

echo ""
echo "Download complete!"
echo "File size: $(du -h "$GHANA_PBF" | cut -f1)"
echo ""
echo "Next steps:"
echo "  1. Run ./scripts/generate-mbtiles.sh to create vector tiles"
echo "  2. Run ./scripts/prepare-osrm.sh to prepare routing data"
