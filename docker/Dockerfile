# Use tilemaker image as base — already multi-arch, binary at /usr/local/bin/tilemaker
FROM ghcr.io/systemed/tilemaker:master

# Install download/extract tools on top
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy scripts directory into the container
COPY scripts/ /app/scripts/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Copy setup entrypoint
COPY docker/setup.sh /app/setup.sh
RUN chmod +x /app/setup.sh

# Output directories will be mounted as volumes:
#   /app/data    → raw OSM PBF
#   /app/tiles   → generated .mbtiles
#   /app/styles  → fonts output
VOLUME ["/app/data", "/app/tiles", "/app/styles"]

ENTRYPOINT ["/app/setup.sh"]
