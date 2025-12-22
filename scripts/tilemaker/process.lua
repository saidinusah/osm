-- Tilemaker processing script for Ghana
-- Based on OpenMapTiles schema

-- Attribute keys to retain
areaKeys = { "natural", "landuse", "leisure", "amenity", "building", "place" }

-- Process nodes (points)
function node_function(node)
    if node == nil then return end

    local place = node:Find("place")
    local name = node:Find("name")
    local amenity = node:Find("amenity")

    -- Places (cities, towns, villages)
    if place ~= "" and name ~= "" then
        node:Layer("place", false)
        node:Attribute("name", name)
        node:Attribute("class", place)

        if place == "city" then
            node:MinZoom(3)
            node:AttributeNumeric("rank", 1)
        elseif place == "town" then
            node:MinZoom(6)
            node:AttributeNumeric("rank", 2)
        elseif place == "village" then
            node:MinZoom(10)
            node:AttributeNumeric("rank", 3)
        elseif place == "hamlet" or place == "suburb" then
            node:MinZoom(12)
            node:AttributeNumeric("rank", 4)
        else
            node:MinZoom(14)
            node:AttributeNumeric("rank", 5)
        end
        return
    end

    -- POIs
    if amenity ~= "" then
        -- EV charging stations - important for AMEV!
        if amenity == "charging_station" then
            node:Layer("poi", false)
            node:Attribute("name", name or "")
            node:Attribute("class", "charging_station")
            node:Attribute("subclass", "ev_charging")
            node:MinZoom(12)
            return
        end
        -- Fuel stations
        if amenity == "fuel" then
            node:Layer("poi", false)
            node:Attribute("name", name or "")
            node:Attribute("class", "fuel")
            node:MinZoom(13)
            return
        end
        -- Parking
        if amenity == "parking" then
            node:Layer("poi", false)
            node:Attribute("name", name or "")
            node:Attribute("class", "parking")
            node:MinZoom(14)
            return
        end
    end
end

-- Process ways (lines and polygons)
function way_function(way)
    if way == nil then return end

    local highway = way:Find("highway")
    local waterway = way:Find("waterway")
    local natural = way:Find("natural")
    local landuse = way:Find("landuse")
    local building = way:Find("building")
    local leisure = way:Find("leisure")
    local amenity = way:Find("amenity")
    local aeroway = way:Find("aeroway")
    local boundary = way:Find("boundary")
    local name = way:Find("name")

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

        way:Layer("transportation", false)
        way:MinZoom(minzoom)
        way:Attribute("class", class)

        if name ~= "" then
            way:Layer("transportation_name", false)
            way:MinZoom(math.max(minzoom, 8))
            way:Attribute("name", name)
            way:Attribute("class", class)
            local ref = way:Find("ref")
            if ref ~= "" then
                way:Attribute("ref", ref)
            end
        end
        return
    end

    -- Waterways
    if waterway ~= "" then
        if waterway == "river" or waterway == "canal" then
            way:Layer("waterway", false)
            way:MinZoom(8)
            way:Attribute("class", waterway)
            if name ~= "" then
                way:Layer("water_name", false)
                way:MinZoom(10)
                way:Attribute("name", name)
                way:Attribute("class", waterway)
            end
        elseif waterway == "stream" then
            way:Layer("waterway", false)
            way:MinZoom(12)
            way:Attribute("class", waterway)
        end
        return
    end

    -- Water bodies
    if natural == "water" or landuse == "reservoir" or landuse == "basin" then
        if way:IsClosed() then
            way:Layer("water", true)
            way:MinZoom(4)
            way:Attribute("class", natural == "water" and "lake" or "reservoir")
            if name ~= "" then
                way:LayerAsCentroid("water_name")
                way:Attribute("name", name)
            end
        end
        return
    end

    -- Coastline
    if natural == "coastline" then
        way:Layer("water", false)
        way:MinZoom(0)
        way:Attribute("class", "ocean")
        return
    end

    -- Land cover
    if natural == "wood" or natural == "forest" or landuse == "forest" then
        way:Layer("landcover", true)
        way:MinZoom(7)
        way:Attribute("class", "wood")
        return
    end

    if natural == "grassland" or natural == "scrub" or natural == "heath" then
        way:Layer("landcover", true)
        way:MinZoom(10)
        way:Attribute("class", "grass")
        return
    end

    -- Land use
    if landuse == "residential" or landuse == "commercial" or landuse == "industrial" or landuse == "retail" then
        way:Layer("landuse", true)
        way:MinZoom(10)
        way:Attribute("class", landuse)
        return
    end

    -- Parks and leisure
    if leisure == "park" or leisure == "garden" or leisure == "playground" then
        way:Layer("park", true)
        way:MinZoom(11)
        way:Attribute("class", leisure)
        if name ~= "" then
            way:Attribute("name", name)
        end
        return
    end

    -- Buildings
    if building ~= "" and building ~= "no" then
        way:Layer("building", true)
        way:MinZoom(13)
        return
    end

    -- Aeroway
    if aeroway == "runway" or aeroway == "taxiway" then
        way:Layer("aeroway", false)
        way:MinZoom(10)
        way:Attribute("class", aeroway)
        return
    end
    if aeroway == "aerodrome" then
        way:Layer("aeroway", true)
        way:MinZoom(10)
        way:Attribute("class", aeroway)
        if name ~= "" then
            way:Attribute("name", name)
        end
        return
    end

    -- Admin boundaries
    if boundary == "administrative" then
        local admin_level = way:Find("admin_level")
        if admin_level == "2" then
            way:Layer("boundary", false)
            way:MinZoom(0)
            way:Attribute("admin_level", 2)
        elseif admin_level == "4" then
            way:Layer("boundary", false)
            way:MinZoom(4)
            way:Attribute("admin_level", 4)
        elseif admin_level == "6" then
            way:Layer("boundary", false)
            way:MinZoom(8)
            way:Attribute("admin_level", 6)
        end
        return
    end
end

-- Handle relations
function relation_scan_function(relation)
    if relation == nil then return end
    local reltype = relation:Find("type")
    if reltype == nil or reltype == "" then return end

    if reltype == "boundary" then
        local boundary = relation:Find("boundary")
        if boundary == "administrative" then
            relation:Accept()
        end
    elseif reltype == "multipolygon" then
        relation:Accept()
    end
end

function relation_function(relation)
    if relation == nil then return end
    local reltype = relation:Find("type")
    if reltype == nil or reltype == "" then return end

    if reltype == "boundary" then
        local boundary = relation:Find("boundary")
        local admin_level = relation:Find("admin_level")
        if boundary == "administrative" and admin_level ~= nil and admin_level ~= "" then
            relation:Layer("boundary", false)
            if admin_level == "2" then
                relation:MinZoom(0)
            elseif admin_level == "4" then
                relation:MinZoom(4)
            else
                relation:MinZoom(8)
            end
            relation:AttributeNumeric("admin_level", tonumber(admin_level) or 8)
        end
    end
end
