# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AMEV Maps (gyeme-maps-server) is a self-hosted GIS infrastructure for Atlantic Meridian EV services in Ghana. It provides vector map tiles, routing, geocoding, spatial queries, and real-time vehicle tracking for the EV charging network. This is **not** an application server — it's containerized infrastructure that other services (Nuxt frontend, AdonisJS backend) integrate with.

## Architecture

Six Docker services orchestrated via `docker-compose.yml`:

- **Nginx** (port 80) — Reverse proxy, serves the viewer SPA from `viewer/`
- **TileServer GL** (port 8085) — Vector tile server, serves `tiles/ghana.mbtiles`. Profile: `tiles`
- **OSRM** (port 5005) — Routing engine using MLD algorithm. Profile: `routing`
- **PostGIS** (port 5455) — Spatial database (`easy_maps` db, user `easy`). Schema in `scripts/init-db.sql`
- **Redis** (port 6380) — Real-time vehicle location tracking via GEOADD/GEORADIUS
- **Nominatim** (port 8082) — Geocoding from OSM data

TileServer and OSRM are **disabled by default** — enable with `--profile tiles` or `--profile routing`.

## Common Commands

```bash
make setup            # Full setup: download data → generate tiles → prepare OSRM → start services
make download-data    # Download Ghana OSM extract from Geofabrik (~80MB)
make generate-tiles   # Generate MBTiles using Tilemaker (→ tiles/ghana.mbtiles)
make prepare-osrm     # Process OSM data for OSRM routing
make up               # Start Docker services
make down             # Stop Docker services
make logs             # Tail all service logs
make quick-test       # Start nginx + postgis + redis only (no tiles needed)
make db-shell         # psql into PostGIS
make redis-shell      # redis-cli into Redis
make clean            # Remove generated data files
```

## Data Pipeline

1. `scripts/download-ghana-data.sh` → downloads `data/ghana-latest.osm.pbf` from Geofabrik
2. `scripts/generate-mbtiles.sh` → runs Tilemaker with `scripts/tilemaker/config.json` + `process.lua` → outputs `tiles/ghana.mbtiles`
3. `scripts/prepare-osrm.sh` → 3-step OSRM processing (extract → partition → customize) → `osrm/` directory
4. `scripts/init-db.sql` → auto-runs on first PostGIS start, creates `amev` schema with tables: `charging_stations`, `vehicle_locations`, `service_areas`, `routes`

## Key Directories

- `scripts/` — Shell scripts for data processing; `tilemaker/` subdir has tile generation config (Lua + JSON)
- `tiles/` — TileServer GL config + generated `.mbtiles` file
- `styles/ghana/style.json` — MapLibre GL style definition (Mapbox Style Spec v8)
- `viewer/index.html` — Interactive map viewer using MapLibre GL JS
- `nginx/conf.d/default.conf` — Nginx proxy/caching config

## Database Schema (amev schema)

All tables use GiST spatial indexes. Key tables:
- `charging_stations` — EV charging points with JSONB fields for connector_types, pricing_info, amenities
- `vehicle_locations` — Fleet tracking with heading/speed/battery_percent
- `service_areas` — Polygon geofences
- `routes` — Saved routes with waypoints and charging_stops (JSONB)

## Technology Notes

- **No package manager** — This is pure Docker/Shell/SQL, no Node.js or Python runtime
- Tile processing uses **Lua** (`scripts/tilemaker/process.lua`) for OSM feature extraction
- The `process.lua` script includes special handling for EV charging station POIs
- Style references MapLibre demo server for fallback sprites/glyphs
- PostgreSQL credentials: user=`easy`, password=`easy_secret_password`, db=`easy_maps`
