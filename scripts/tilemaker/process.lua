-- Tilemaker v3 processing script for Ghana
-- Based on OpenMapTiles schema
-- Note: v3 API uses direct function calls (Find, Layer, etc.) instead of object methods

-- Attribute keys that indicate a closed way should be treated as a polygon
areaKeys = { natural="yes", landuse="yes", leisure="yes", amenity="yes", building="yes", place="yes" }

-- Filter: only process nodes with these tags
node_keys = { "place", "amenity" }

-- Filter: only process ways with these tags
way_keys = { "highway", "waterway", "natural", "landuse", "building", "leisure", "amenity", "aeroway", "boundary" }

-- Process nodes (points)
function node_function()
    local place = Find("place")
    local name = Find("name")
    local amenity = Find("amenity")

    -- Places (cities, towns, villages)
    if place ~= "" and name ~= "" then
        Layer("place", false)
        Attribute("name", name)
        Attribute("class", place)

        if place == "city" then
            MinZoom(3)
            AttributeNumeric("rank", 1)
        elseif place == "town" then
            MinZoom(6)
            AttributeNumeric("rank", 2)
        elseif place == "village" then
            MinZoom(10)
            AttributeNumeric("rank", 3)
        elseif place == "hamlet" or place == "suburb" then
            MinZoom(12)
            AttributeNumeric("rank", 4)
        else
            MinZoom(14)
            AttributeNumeric("rank", 5)
        end
        return
    end

    -- POIs
    if amenity ~= "" then
        -- EV charging stations - important for AMEV!
        if amenity == "charging_station" then
            Layer("poi", false)
            Attribute("name", name)
            Attribute("class", "charging_station")
            Attribute("subclass", "ev_charging")
            MinZoom(12)
            return
        end
        -- Fuel stations
        if amenity == "fuel" then
            Layer("poi", false)
            Attribute("name", name)
            Attribute("class", "fuel")
            MinZoom(13)
            return
        end
        -- Parking
        if amenity == "parking" then
            Layer("poi", false)
            Attribute("name", name)
            Attribute("class", "parking")
            MinZoom(14)
            return
        end
    end
end

-- Process ways (lines and polygons)
function way_function()
    local highway = Find("highway")
    local waterway = Find("waterway")
    local natural = Find("natural")
    local landuse = Find("landuse")
    local building = Find("building")
    local leisure = Find("leisure")
    local amenity = Find("amenity")
    local aeroway = Find("aeroway")
    local boundary = Find("boundary")
    local name = Find("name")

    -- Transportation (roads)
    if highway ~= "" then
        local minzoom = 14
        local class = highway

        if highway == "motorway" or highway == "motorway_link" then
            minzoom = 4
            class = "motorway"
        elseif highway == "trunk" or highway == "trunk_link" then
            minzoom = 5
            class = "trunk"
        elseif highway == "primary" or highway == "primary_link" then
            minzoom = 6
            class = "primary"
        elseif highway == "secondary" or highway == "secondary_link" then
            minzoom = 8
            class = "secondary"
        elseif highway == "tertiary" or highway == "tertiary_link" then
            minzoom = 10
            class = "tertiary"
        elseif highway == "residential" or highway == "living_street" then
            minzoom = 12
            class = "minor"
        elseif highway == "unclassified" then
            minzoom = 12
            class = "minor"
        elseif highway == "service" then
            minzoom = 13
            class = "service"
        elseif highway == "track" then
            minzoom = 13
            class = "track"
        elseif highway == "path" or highway == "footway" or highway == "cycleway" then
            minzoom = 14
            class = "path"
        end

        Layer("transportation", false)
        MinZoom(minzoom)
        Attribute("class", class)

        if name ~= "" then
            Layer("transportation_name", false)
            MinZoom(math.max(minzoom, 8))
            Attribute("name", name)
            Attribute("class", class)
            local ref = Find("ref")
            if ref ~= "" then
                Attribute("ref", ref)
            end
        end
        return
    end

    -- Waterways
    if waterway ~= "" then
        if waterway == "river" or waterway == "canal" then
            Layer("waterway", false)
            MinZoom(8)
            Attribute("class", waterway)
            if name ~= "" then
                Layer("water_name", false)
                MinZoom(10)
                Attribute("name", name)
                Attribute("class", waterway)
            end
        elseif waterway == "stream" then
            Layer("waterway", false)
            MinZoom(12)
            Attribute("class", waterway)
        end
        return
    end

    -- Water bodies
    if natural == "water" or landuse == "reservoir" or landuse == "basin" then
        if IsClosed() then
            Layer("water", true)
            MinZoom(4)
            Attribute("class", natural == "water" and "lake" or "reservoir")
            if name ~= "" then
                LayerAsCentroid("water_name")
                Attribute("name", name)
            end
        end
        return
    end

    -- Coastline
    if natural == "coastline" then
        Layer("water", false)
        MinZoom(0)
        Attribute("class", "ocean")
        return
    end

    -- Land cover
    if natural == "wood" or natural == "forest" or landuse == "forest" then
        Layer("landcover", true)
        MinZoom(7)
        Attribute("class", "wood")
        return
    end

    if natural == "grassland" or natural == "scrub" or natural == "heath" then
        Layer("landcover", true)
        MinZoom(10)
        Attribute("class", "grass")
        return
    end

    -- Land use
    if landuse == "residential" or landuse == "commercial" or landuse == "industrial" or landuse == "retail" then
        Layer("landuse", true)
        MinZoom(10)
        Attribute("class", landuse)
        return
    end

    -- Parks and leisure
    if leisure == "park" or leisure == "garden" or leisure == "playground" then
        Layer("park", true)
        MinZoom(11)
        Attribute("class", leisure)
        if name ~= "" then
            Attribute("name", name)
        end
        return
    end

    -- Buildings
    if building ~= "" and building ~= "no" then
        Layer("building", true)
        MinZoom(13)
        return
    end

    -- Aeroway
    if aeroway == "runway" or aeroway == "taxiway" then
        Layer("aeroway", false)
        MinZoom(10)
        Attribute("class", aeroway)
        return
    end
    if aeroway == "aerodrome" then
        Layer("aeroway", true)
        MinZoom(10)
        Attribute("class", aeroway)
        if name ~= "" then
            Attribute("name", name)
        end
        return
    end

    -- Admin boundaries
    if boundary == "administrative" then
        local admin_level = Find("admin_level")
        if admin_level == "2" then
            Layer("boundary", false)
            MinZoom(0)
            Attribute("admin_level", 2)
        elseif admin_level == "4" then
            Layer("boundary", false)
            MinZoom(4)
            Attribute("admin_level", 4)
        elseif admin_level == "6" then
            Layer("boundary", false)
            MinZoom(8)
            Attribute("admin_level", 6)
        end
        return
    end
end

-- Handle relations
function relation_scan_function()
    local reltype = Find("type")
    if reltype == "" then return end

    if reltype == "boundary" then
        local boundary = Find("boundary")
        if boundary == "administrative" then
            Accept()
        end
    elseif reltype == "multipolygon" then
        Accept()
    end
end

function relation_function()
    local reltype = Find("type")
    if reltype == "" then return end

    if reltype == "boundary" then
        local boundary = Find("boundary")
        local admin_level = Find("admin_level")
        if boundary == "administrative" and admin_level ~= "" then
            Layer("boundary", false)
            if admin_level == "2" then
                MinZoom(0)
            elseif admin_level == "4" then
                MinZoom(4)
            else
                MinZoom(8)
            end
            AttributeNumeric("admin_level", tonumber(admin_level) or 8)
        end
    end
end
