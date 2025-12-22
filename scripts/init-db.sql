-- Initialize PostGIS database for AMEV Maps
-- This creates tables for storing business data (charging stations, etc.)

-- Enable PostGIS extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Create schema for AMEV data
CREATE SCHEMA IF NOT EXISTS amev;

-- Charging stations table
CREATE TABLE IF NOT EXISTS amev.charging_stations (
    id SERIAL PRIMARY KEY,
    external_id VARCHAR(255) UNIQUE,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    city VARCHAR(255),
    region VARCHAR(255),
    country VARCHAR(100) DEFAULT 'Ghana',
    location GEOMETRY(Point, 4326) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    connector_types JSONB DEFAULT '[]',
    max_power_kw NUMERIC(10, 2),
    operator_name VARCHAR(255),
    network_name VARCHAR(255),
    is_public BOOLEAN DEFAULT true,
    pricing_info JSONB,
    amenities JSONB DEFAULT '[]',
    photos JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index on location
CREATE INDEX IF NOT EXISTS idx_charging_stations_location
ON amev.charging_stations USING GIST (location);

-- Index on status for filtering
CREATE INDEX IF NOT EXISTS idx_charging_stations_status
ON amev.charging_stations (status);

-- Index on city/region for regional queries
CREATE INDEX IF NOT EXISTS idx_charging_stations_city
ON amev.charging_stations (city);

CREATE INDEX IF NOT EXISTS idx_charging_stations_region
ON amev.charging_stations (region);

-- Live vehicle locations table (for fleet tracking)
CREATE TABLE IF NOT EXISTS amev.vehicle_locations (
    id SERIAL PRIMARY KEY,
    vehicle_id VARCHAR(255) NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL,
    heading NUMERIC(5, 2),
    speed_kmh NUMERIC(6, 2),
    battery_percent NUMERIC(5, 2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index for vehicle locations
CREATE INDEX IF NOT EXISTS idx_vehicle_locations_location
ON amev.vehicle_locations USING GIST (location);

-- Index on vehicle_id and timestamp for history queries
CREATE INDEX IF NOT EXISTS idx_vehicle_locations_vehicle_time
ON amev.vehicle_locations (vehicle_id, timestamp DESC);

-- Service areas / geofences table
CREATE TABLE IF NOT EXISTS amev.service_areas (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,
    area_type VARCHAR(50) DEFAULT 'service',
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create spatial index for service areas
CREATE INDEX IF NOT EXISTS idx_service_areas_geometry
ON amev.service_areas USING GIST (geometry);

-- Routes table (pre-calculated or saved routes)
CREATE TABLE IF NOT EXISTS amev.routes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    origin GEOMETRY(Point, 4326) NOT NULL,
    destination GEOMETRY(Point, 4326) NOT NULL,
    waypoints GEOMETRY(MultiPoint, 4326),
    route_geometry GEOMETRY(LineString, 4326),
    distance_meters NUMERIC(12, 2),
    duration_seconds INTEGER,
    charging_stops JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Spatial indexes for routes
CREATE INDEX IF NOT EXISTS idx_routes_origin
ON amev.routes USING GIST (origin);

CREATE INDEX IF NOT EXISTS idx_routes_destination
ON amev.routes USING GIST (destination);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_charging_stations_updated_at
    BEFORE UPDATE ON amev.charging_stations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_service_areas_updated_at
    BEFORE UPDATE ON amev.service_areas
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert some sample charging stations in Ghana for testing
INSERT INTO amev.charging_stations (name, address, city, region, location, connector_types, max_power_kw)
VALUES
    ('AMEV Accra Central', 'Independence Ave, Accra', 'Accra', 'Greater Accra', ST_SetSRID(ST_MakePoint(-0.1870, 5.5560), 4326), '["CCS2", "CHAdeMO", "Type2"]', 150),
    ('AMEV Kumasi Hub', 'Harper Road, Kumasi', 'Kumasi', 'Ashanti', ST_SetSRID(ST_MakePoint(-1.6163, 6.6885), 4326), '["CCS2", "Type2"]', 100),
    ('AMEV Tema Port', 'Harbour Road, Tema', 'Tema', 'Greater Accra', ST_SetSRID(ST_MakePoint(-0.0167, 5.6698), 4326), '["CCS2", "CHAdeMO"]', 350),
    ('AMEV Cape Coast', 'Chapel Square, Cape Coast', 'Cape Coast', 'Central', ST_SetSRID(ST_MakePoint(-1.2466, 5.1053), 4326), '["CCS2", "Type2"]', 50),
    ('AMEV Takoradi', 'Market Circle, Takoradi', 'Takoradi', 'Western', ST_SetSRID(ST_MakePoint(-1.7557, 4.8929), 4326), '["CCS2", "Type2"]', 75)
ON CONFLICT (external_id) DO NOTHING;

-- Print success message
DO $$
BEGIN
    RAISE NOTICE 'AMEV Maps database initialized successfully!';
    RAISE NOTICE 'Sample charging stations created: %', (SELECT COUNT(*) FROM amev.charging_stations);
END $$;
