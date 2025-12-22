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
