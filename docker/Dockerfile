FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    ca-certificates \
    sqlite3 \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install tilemaker binary (avoids Docker-in-Docker for tile generation)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then TM_ARCH="linux-amd64"; \
    elif [ "$ARCH" = "arm64" ]; then TM_ARCH="linux-arm64"; \
    else echo "Unsupported arch: $ARCH" && exit 1; fi && \
    curl -L -o /tmp/tilemaker.gz \
        "https://github.com/systemed/tilemaker/releases/download/v3.0.0/tilemaker-${TM_ARCH}.gz" && \
    gunzip /tmp/tilemaker.gz && \
    mv /tmp/tilemaker /usr/local/bin/tilemaker && \
    chmod +x /usr/local/bin/tilemaker

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
