#!/bin/bash

# Prepare OSRM routing data for Ghana
# This processes OSM data for the OSRM routing engine

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
OSRM_DIR="$PROJECT_DIR/osrm"

GHANA_PBF="$DATA_DIR/ghana-latest.osm.pbf"

if [ ! -f "$GHANA_PBF" ]; then
    echo "Error: Ghana OSM data not found at $GHANA_PBF"
    echo "Run ./scripts/download-ghana-data.sh first"
    exit 1
fi

mkdir -p "$OSRM_DIR"

echo "=== Preparing OSRM Routing Data for Ghana ==="
echo "Input: $GHANA_PBF"
echo "Output: $OSRM_DIR/ghana-latest.osrm"
echo ""

# Copy PBF to OSRM directory for processing
cp "$GHANA_PBF" "$OSRM_DIR/ghana-latest.osm.pbf"

echo "Step 1/3: Extracting road network..."
docker run --rm \
    -v "$OSRM_DIR:/data" \
    osrm/osrm-backend:latest \
    osrm-extract -p /opt/car.lua /data/ghana-latest.osm.pbf

echo ""
echo "Step 2/3: Partitioning graph (MLD algorithm)..."
docker run --rm \
    -v "$OSRM_DIR:/data" \
    osrm/osrm-backend:latest \
    osrm-partition /data/ghana-latest.osrm

echo ""
echo "Step 3/3: Customizing graph..."
docker run --rm \
    -v "$OSRM_DIR:/data" \
    osrm/osrm-backend:latest \
    osrm-customize /data/ghana-latest.osrm

echo ""
echo "OSRM preparation complete!"
echo ""
echo "You can now start the OSRM service with docker-compose."

# Clean up the copy
rm -f "$OSRM_DIR/ghana-latest.osm.pbf"
