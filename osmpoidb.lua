-- lua script for osm2pgsql to import and update osmpoidb
--
-- (c) 2022 Sven Geggus <sven-osm@geggus-net>

-- Unify the following keys in the database
local unified_keys = {
    booking = "reservation",
    ["contact:phone"] = "phone",
    ["contact:fax"] = "fax",
    ["contact:website"] = "website",
    ["contact:email"] = "email",
    url = "website"
};


local allowed_polygon_tags = {
    amenity='*',
    historic='*',
    leisure='*',
    shop='*',
    tourism='*',
    industrial='*',
    craft='*',
    man_made='*',
    healthcare='*',
    emergency='*',
    playground='*',
    camp_site='*',
    building={'cabin','static_caravan'}
}

local allowed_line_tags = {
    playground='*',
    amenity='*'
}

local allowed_point_tags = {
    amenity='*',
    historic='*',
    leisure='*', 
    shop='*',    
    tourism='*', 
    industrial='*',
    craft='*',
    man_made='*',
    healthcare='*',
    emergency='*',
    highway='*',
    -- It is IMO a bad tagging decision that we need those here :(
    playground='*',
    camp_site='*',
    building={'cabin','static_caravan'}
}

function contains(list, x)
  for _, v in pairs(list) do
    if v == x then return true end
  end
  return false
end

function has_any_of(tags, list)
  for k,v in pairs(tags) do
    if list[k] then
      if (list[k] == '*') then
        return true
      else
        if contains(list[k],v) then
          return true
        end
      end
    end
  end
  return false
end

-- unify_keys and 'addr:country' if set
function unify_keys(tags)
  for k,v in pairs(unified_keys) do
    if (tags[k] ~= nil) then
      tags[unified_keys[k]]=tags[k];
      tags[k]=nil;
    end
  end
  if (tags['addr:country'] ~= nil) then
    
  end
end

-- The global variable "osm2pgsql" is used to talk to the main osm2pgsql code.
-- You can, for instance, get the version of osm2pgsql:
print('osm2pgsql version: ' .. osm2pgsql.version)

-- A place to store the SQL tables we will define shortly.
local tables = {}

tables.point = osm2pgsql.define_table{
    name = 'osm_poi_point',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only=true },
        { column = 'timestamp', sql_type = 'timestamp' },
        { column = 'tags',  type = 'hstore' },
        { column = 'geom',  type = 'geometry', projection = 'latlong'  },
    }
}

tables.line = osm2pgsql.define_table{
    name = 'osm_poi_line',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only=true },
        { column = 'timestamp', sql_type = 'timestamp' },
        { column = 'tags',  type = 'hstore' },
        { column = 'geom',  type = 'geometry', projection = 'latlong'  },
    }
}

tables.polygon = osm2pgsql.define_table{
    name = 'osm_poi_poly',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'id', sql_type = 'serial', create_only=true },
        { column = 'timestamp', sql_type = 'timestamp' },
        { column = 'tags',  type = 'hstore' },
        { column = 'geom',  type = 'geometry', projection = 'latlong'  },
    }
}

tables.siterel = osm2pgsql.define_table{
    name = 'osm_poi_camp_siterel',
    ids = { type = 'relation', id_column = 'site_id'},
    columns = {
        { column = 'id', sql_type = 'serial', create_only=true },
        { column = 'member_id', type = 'bigint' },
        { column = 'member_type', type = 'text' },
        { column = 'site_tags',  type = 'hstore' }
    }    
}

-- Debug output: Show definition of tables
for name, table in pairs(tables) do
    print("\ntable '" .. name .. "':")
    print("  name='" .. table:name() .. "'")
--    print("  columns=" .. inspect(table:columns()))
end

-- Called for every node in the input. The `object` argument contains all the
-- attributes of the node like `id`, `version`, etc. as well as all tags as a
-- Lua table (`object.tags`).
function osm2pgsql.process_node(object)

    if not (has_any_of(object.tags, allowed_point_tags)) then
        return
    end

    unify_keys(object.tags)

    tables.point:add_row({
        tags = object.tags,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', object.timestamp),
        geom = { create = 'point' }
    })

end

-- Called for every way in the input. The `object` argument contains the same
-- information as with nodes and additionally a boolean `is_closed` flag and
-- the list of node IDs referenced by the way (`object.nodes`).
function osm2pgsql.process_way(object)

    if not ((has_any_of(object.tags, allowed_polygon_tags)) or has_any_of(object.tags, allowed_line_tags)) then
    	return
    end

    unify_keys(object.tags)

    -- Very simple check to decide whether a way is a polygon or not.
    -- Good enough in this case as we have only a small list of allowed tags
    if object.is_closed then
    	if (has_any_of(object.tags, allowed_polygon_tags)) then
            tables.polygon:add_row({
                tags = object.tags,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', object.timestamp),
                geom = { create = 'area' }
            })
        end
    else
        if (has_any_of(object.tags, allowed_line_tags)) then
            tables.line:add_row({
                tags = object.tags,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', object.timestamp),
                geom = { create = 'line' }
            })
        end
    end
end

-- Called for every relation in the input. The `object` argument contains the
-- same information as with nodes and additionally an array of members
-- (`object.members`).
function osm2pgsql.process_relation(object)

    if not (has_any_of(object.tags, allowed_polygon_tags)) then
        return
    end
    
    if object.tags.type == 'site' then
      if object.tags.tourism == 'camp_site' or
         object.tags.site == 'camp_site' then
         for _,member in ipairs(object.members) do
           tables.siterel:insert({
             member_id = member.ref,
             member_type = string.upper(member.type),
             site_tags = object.tags 
           })
         end
      end
    end

    unify_keys(object.tags)
    
    -- Store multipolygons and boundaries as polygons
    if object.tags.type == 'multipolygon' or
       object.tags.type == 'boundary' then
         tables.polygon:add_row({
            tags = object.tags,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', object.timestamp),
            geom = { create = 'area' }
        })
    end
end

