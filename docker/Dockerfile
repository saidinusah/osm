# Use tilemaker image as base — multi-arch, binary at /usr/src/app/tilemaker.
FROM ghcr.io/systemed/tilemaker:master

# Install download/extract tools on top
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Tilemaker's image places the binary at /usr/src/app/tilemaker and relies on
# its ENTRYPOINT to invoke it. We override ENTRYPOINT below, so symlink the
# binary into PATH and keep its bundled resources accessible from the same
# working directory the upstream image uses.
RUN ln -sf /usr/src/app/tilemaker /usr/local/bin/tilemaker

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

# Reset the tilemaker image's entrypoint so our setup.sh runs directly
ENTRYPOINT []
CMD ["/bin/bash", "/app/setup.sh"]
