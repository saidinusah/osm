#!/bin/sh
# Idempotent OSRM graph preparation.
# Reads the Ghana PBF written by the main `setup` service, then runs
# osrm-extract -> osrm-partition -> osrm-customize. Skips if a graph
# is already present in the volume.
#
# Mounted as:
#   /input  → osm_data volume (read-only, contains ghana-latest.osm.pbf)
#   /data   → osrm_data volume (read-write, ghana-latest.osrm.* lives here)

set -e

INPUT_PBF="/input/ghana-latest.osm.pbf"
DATA_DIR="/data"
WORK_PBF="${DATA_DIR}/ghana-latest.osm.pbf"
OSRM_BASE="${DATA_DIR}/ghana-latest.osrm"
PROFILE="/opt/car.lua"

if [ ! -f "$INPUT_PBF" ]; then
    echo "ERROR: $INPUT_PBF not found. Did the setup service run?"
    exit 1
fi

# Skip if MLD graph is already prepared.
if [ -f "${OSRM_BASE}.partition" ] && \
   [ -f "${OSRM_BASE}.cells" ] && \
   [ -f "${OSRM_BASE}.mldgr" ]; then
    echo "OSRM graph already prepared at ${OSRM_BASE}.* — skipping."
    exit 0
fi

echo "Copying PBF into osrm volume..."
cp "$INPUT_PBF" "$WORK_PBF"

echo ""
echo "Step 1/3 — osrm-extract"
osrm-extract -p "$PROFILE" "$WORK_PBF"

echo ""
echo "Step 2/3 — osrm-partition"
osrm-partition "$OSRM_BASE"

echo ""
echo "Step 3/3 — osrm-customize"
osrm-customize "$OSRM_BASE"

echo ""
echo "OSRM graph ready at ${OSRM_BASE}.*"
