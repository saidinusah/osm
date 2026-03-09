# AMEV Maps - Makefile

.PHONY: help setup download-data generate-tiles prepare-osrm up down logs shell clean

# Default target
help:
	@echo "AMEV Maps - Available commands:"
	@echo ""
	@echo "  make setup          - Complete setup (download data, generate tiles, start services)"
	@echo "  make download-data  - Download Ghana OSM data from Geofabrik"
	@echo "  make generate-tiles - Generate MBTiles from OSM data"
	@echo "  make prepare-osrm   - Prepare OSRM routing data"
	@echo "  make up             - Start all Docker services"
	@echo "  make down           - Stop all Docker services"
	@echo "  make logs           - View service logs"
	@echo "  make shell          - Open shell in tileserver container"
	@echo "  make clean          - Remove generated data"
	@echo ""

# Complete setup
setup: download-data generate-tiles prepare-osrm up
	@echo ""
	@echo "Setup complete! Open http://localhost in your browser."

# Download Ghana OSM data
download-data:
	@chmod +x scripts/*.sh
	@./scripts/download-ghana-data.sh

# Generate vector tiles
generate-tiles:
	@./scripts/generate-mbtiles.sh


# Download fonts
download-fonts:
	@./scripts/download-fonts.sh

# Prepare OSRM routing data
prepare-osrm:
	@./scripts/prepare-osrm.sh

# Start Docker services
up:
	docker-compose up -d
	@echo ""
	@echo "Services started:"
	@echo "  - Map viewer: http://localhost:8085"
	@echo "  - TileServer: http://localhost:8081"
	@echo "  - OSRM: http://localhost:5000"
	@echo "  - PostGIS: localhost:5432"
	@echo "  - Redis: localhost:6379"

# Stop Docker services
down:
	docker-compose down

# View logs
logs:
	docker-compose logs -f

# Open shell in tileserver container
shell:
	docker-compose exec tileserver /bin/sh

# Clean generated data
clean:
	rm -f tiles/ghana.mbtiles
	rm -f data/ghana-latest.osm.pbf
	rm -rf osrm/*.osrm*
	@echo "Generated data cleaned. Run 'make setup' to regenerate."

# Quick test - start with fallback (no tiles needed)
quick-test:
	docker-compose up -d nginx postgis redis
	@echo ""
	@echo "Quick test mode started (OSM raster tiles fallback)"
	@echo "Open http://localhost in your browser."

# Database shell
db-shell:
	docker-compose exec postgis psql -U easy -d easy_maps

# Redis shell
redis-shell:
	docker-compose exec redis redis-cli



# 5.6221056,-0.178221;5.6670413,-0.179723;5.6682572,-0.2110518
