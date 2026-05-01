# AMEV Maps - Self-Hosted Map Infrastructure

Self-hosted map tile server for Atlantic Meridian EV services, using OpenStreetMap data for Ghana.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Browser   │────▶│    Nginx     │────▶│  TileServer GL  │
│  (MapLibre) │     │  (caching)   │     │   (tiles/styles)│
└─────────────┘     └──────────────┘     └─────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │     OSRM     │
                    │  (routing)   │
                    └──────────────┘

┌─────────────┐     ┌──────────────┐
│   PostGIS   │     │    Redis     │
│  (spatial)  │     │  (realtime)  │
└─────────────┘     └──────────────┘
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Nginx | 80 | Reverse proxy with tile caching |
| TileServer GL | 8080 | Vector tile server |
| OSRM | 5000 | Routing engine |
| PostGIS | 5432 | Spatial database |
| Redis | 6379 | Real-time data |

## Quick Start

### Prerequisites

- Docker and Docker Compose
- ~5GB disk space for Ghana map data
- Internet connection (for initial data download)

### 1. Download Ghana Map Data

```bash
chmod +x scripts/*.sh
./scripts/download-ghana-data.sh
```

This downloads the Ghana OSM extract (~80MB) from Geofabrik.

### 2. Generate Vector Tiles

```bash
./scripts/generate-mbtiles.sh
```

This creates `tiles/ghana.mbtiles` (~200MB) using tilemaker.

### 3. Prepare Routing Data

```bash
./scripts/prepare-osrm.sh
```

This prepares OSRM routing data for Ghana.

### 4. Start Services

```bash
docker-compose up -d
```

### 5. Access the Map

Open http://localhost in your browser.

## Usage

### Map Viewer

The built-in viewer provides:
- Interactive map of Ghana with self-hosted tiles
- Sample charging station markers
- Layer toggles
- Real-time coordinate display

### API Endpoints

**Tiles**
```
GET /tiles/styles/ghana/style.json   # Map style
GET /tiles/data/ghana/{z}/{x}/{y}.pbf # Vector tiles
GET /tiles/fonts/{fontstack}/{range}.pbf # Fonts
```

**Routing (OSRM)**
```
GET /route/driving/{lng1},{lat1};{lng2},{lat2}?overview=full
```

**Example:**
```bash
# Get route from Accra to Kumasi
curl "http://localhost/route/driving/-0.187,5.556;-1.616,6.688?overview=full"
```

### PostGIS Database

Connect to the spatial database:
```bash
psql postgresql://easy:easy_secret_password@localhost:5432/easy_maps
```

Query charging stations:
```sql
SELECT name, ST_AsText(location)
FROM easy.charging_stations;

-- Find stations within 10km of a point
SELECT name, ST_Distance(
    location::geography,
    ST_SetSRID(ST_MakePoint(-0.187, 5.556), 4326)::geography
) as distance_m
FROM easy.charging_stations
WHERE ST_DWithin(
    location::geography,
    ST_SetSRID(ST_MakePoint(-0.187, 5.556), 4326)::geography,
    10000
);
```

### Redis Geo Commands

Store and query vehicle locations:
```bash
redis-cli

# Add vehicle location
GEOADD vehicles -0.187 5.556 "vehicle:001"

# Find vehicles within 5km
GEORADIUS vehicles -0.187 5.556 5 km WITHCOORD WITHDIST
```

## Integration with AMEV Master

### Frontend (Nuxt)

```typescript
// composables/useMap.ts
export function useMap() {
  const mapConfig = {
    style: 'http://localhost/tiles/styles/ghana/style.json',
    center: [-1.0232, 7.9465],
    zoom: 6
  }

  function initMap(container: string) {
    return new maplibregl.Map({
      container,
      style: mapConfig.style,
      center: mapConfig.center,
      zoom: mapConfig.zoom
    })
  }

  async function getRoute(start: [number, number], end: [number, number]) {
    const response = await fetch(
      `http://localhost/route/driving/${start.join(',')};${end.join(',')}?overview=full`
    )
    return response.json()
  }

  return { initMap, getRoute, mapConfig }
}
```

### Backend (AdonisJS)

```typescript
// services/spatial_service.ts
import { Pool } from 'pg'

export class SpatialService {
  private pool: Pool

  constructor() {
    this.pool = new Pool({
      host: 'localhost',
      port: 5432,
      database: 'easy_maps',
      user: 'easy',
      password: 'easy_secret_password'
    })
  }

  async findNearbyStations(lat: number, lng: number, radiusKm: number) {
    const result = await this.pool.query(`
      SELECT id, name, address,
             ST_X(location::geometry) as lng,
             ST_Y(location::geometry) as lat,
             ST_Distance(
               location::geography,
               ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
             ) as distance_m
      FROM easy.charging_stations
      WHERE ST_DWithin(
        location::geography,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        $3
      )
      ORDER BY distance_m
    `, [lng, lat, radiusKm * 1000])

    return result.rows
  }
}
```

## Customization

### Modify Map Style

Edit `styles/ghana/style.json` to customize:
- Colors for roads, buildings, water
- Label fonts and sizes
- Layer visibility at different zoom levels

### Add Custom Layers

Add GeoJSON layers in the viewer:
```javascript
map.addSource('my-data', {
  type: 'geojson',
  data: myGeoJsonData
});

map.addLayer({
  id: 'my-layer',
  type: 'circle',
  source: 'my-data',
  paint: {
    'circle-color': '#ff0000',
    'circle-radius': 8
  }
});
```

## Production deployment (Coolify)

The production stack is `docker-compose.prod.yml`. It uses the `coolify` external Docker network and Traefik labels for Let's Encrypt TLS, plus a one-shot `setup` service that pulls the Ghana OSM extract, downloads fonts, and builds the MBTiles into named volumes — and a one-shot `osrm-setup` service that prepares the OSRM routing graph.

### 1. DNS

Point an A record at the Hetzner VPS IP, e.g.:

```
maps-nginx.saidinusah.com  →  <vps_ip>
```

### 2. Coolify resource

Create a new **Docker Compose** application in Coolify pointing at this repo. Pick `docker-compose.prod.yml` as the compose file. Set the network to `coolify` (Coolify auto-creates this).

### 3. Environment variables

Copy [.env.example](.env.example) into Coolify's environment-variable UI and fill in:

| Variable | Notes |
|---|---|
| `DOMAIN` | The public hostname Traefik will issue a cert for (e.g. `maps-nginx.saidinusah.com`) |
| `POSTGRES_PASSWORD` | Long random — `openssl rand -hex 32` |
| `REDIS_PASSWORD` | Long random |
| `NOMINATIM_PASSWORD` | Long random — Nominatim's internal Postgres password |
| `MAPS_INTERNAL_API_KEY` | Long random — `openssl rand -hex 32`. The gyeme-api backend sends this as `X-Maps-Key` to access `/geocode/*` and `/routing/*` |
| `TILES_CORS_ORIGIN` | `*` while wiring up; lock to your app domains in steady-state |

### 4. First deploy

```bash
# In Coolify, click Deploy.
```

What happens, in order:

1. **`setup` (~10 min)** — downloads `ghana-latest.osm.pbf` (~150 MB), pulls OpenMapTiles fonts, runs Tilemaker → `ghana.mbtiles` (~280 MB).
2. **`osrm-setup` (~5–15 min)** — copies the PBF into the OSRM volume and runs `osrm-extract → osrm-partition → osrm-customize` against the `car.lua` profile. Idempotent: skips if `ghana-latest.osrm.{partition,cells,mldgr}` already exist.
3. **`tileserver`, `osrm`, `postgis`, `redis`** start once their respective setup deps complete.
4. **`nominatim` starts and indexes the Ghana extract — this takes 30–60 minutes**. The healthcheck has `start_period: 3600s` so Coolify won't mark it unhealthy mid-index. Watch progress via `docker compose logs -f nominatim`.
5. **`nginx`** starts and Traefik picks up the route. Cert issuance happens within ~30 s if DNS is correct.

Total first-deploy time: ~45–75 min. Subsequent deploys reuse the volumes and start in seconds.

### 5. Verify

```bash
# Public — apps fetch tiles directly
curl https://$DOMAIN/healthz                                                         # → "ok"
curl https://$DOMAIN/tiles/styles/ghana/style.json | head                            # → MapLibre style JSON

# Internal — must include X-Maps-Key
curl -i https://$DOMAIN/geocode/search?q=Accra                                       # → 403
curl -i -H "X-Maps-Key: $MAPS_INTERNAL_API_KEY" https://$DOMAIN/geocode/search?q=Accra
curl -i -H "X-Maps-Key: $MAPS_INTERNAL_API_KEY" \
     "https://$DOMAIN/routing/route/v1/driving/-0.187,5.604;-0.197,5.614?overview=full&geometries=polyline"
```

Wire the gyeme-api backend by setting:

```
NOMINATIM_URL=https://maps-nginx.saidinusah.com/geocode
OSRM_URL=https://maps-nginx.saidinusah.com/routing
MAPS_INTERNAL_API_KEY=<same value as in Coolify>
```

### 6. Refreshing OSM data

Re-running the deploy doesn't re-download data. To pull a fresh extract:

```bash
# In Coolify shell on the VPS:
docker compose -f docker-compose.prod.yml stop nominatim osrm tileserver
docker volume rm <project>_osm_data <project>_tiles_data <project>_osrm_data
docker compose -f docker-compose.prod.yml up -d
```

(The setup containers will rerun; expect another ~45 min downtime for Nominatim re-index.)

## Maintenance

### Update Map Data

```bash
# Re-download latest OSM data
./scripts/download-ghana-data.sh

# Regenerate tiles
./scripts/generate-mbtiles.sh

# Regenerate routing
./scripts/prepare-osrm.sh

# Restart services
docker-compose restart tileserver osrm
```

### Clear Tile Cache

```bash
docker-compose exec nginx rm -rf /var/cache/nginx/tiles/*
```

### View Logs

```bash
docker-compose logs -f tileserver
docker-compose logs -f nginx
```

## Troubleshooting

### Tiles not loading
1. Check TileServer GL is running: `docker-compose ps`
2. Verify `tiles/ghana.mbtiles` exists
3. Check browser console for errors
4. Verify style.json source URL is correct

### Routing not working
1. Ensure OSRM data was prepared successfully
2. Check `osrm/` directory contains `.osrm` files
3. Test OSRM directly: `curl http://localhost:5000/route/v1/driving/-0.187,5.556;-1.616,6.688`

### Database connection issues
1. Wait for PostGIS to fully start (can take 30s)
2. Check credentials in docker-compose.yml
3. Verify port 5432 is not in use by another PostgreSQL instance

## Project Structure

```
easy-maps/
├── docker-compose.yml      # Service orchestration
├── tiles/
│   ├── config.json         # TileServer GL config
│   └── ghana.mbtiles       # Generated tiles (after setup)
├── styles/
│   └── ghana/
│       └── style.json      # MapLibre style
├── nginx/
│   └── conf.d/
│       └── default.conf    # Nginx caching config
├── osrm/                   # OSRM routing data (after setup)
├── scripts/
│   ├── download-ghana-data.sh
│   ├── generate-mbtiles.sh
│   ├── prepare-osrm.sh
│   ├── init-db.sql
│   └── tilemaker/          # Tilemaker config
├── viewer/
│   └── index.html          # MapLibre test viewer
└── data/                   # Downloaded OSM data
```
