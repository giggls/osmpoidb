-- create MATERIALIZED VIEW to be used
-- in json output

CREATE OR REPLACE VIEW osm_poi_all AS
SELECT    osm_id,tags,geom
FROM      osm_poi_poly
UNION ALL
SELECT    osm_id,tags,geom
FROM      osm_poi_point;


CREATE MATERIALIZED VIEW osm_poi_campsites AS
SELECT    (-1*poly.osm_id)      AS osm_id,
          poly.geom             AS geom,
-- this will remove the redundant key 'tourism' = 'camp_site' from hstore
          poly.tags - 'tourism'::text AS tags,
          'way' as osm_type,
          CASE WHEN poly.tags->'access' IN ('private','members') THEN 'private'
               WHEN poly.tags->'group_only' = 'yes' THEN 'group_only'
               WHEN poly.tags->'backcountry' = 'yes' THEN 'backcountry'
          ELSE 'standard' END AS category,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'toilets', false)) AS toilets,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'shower', false)) AS shower,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'swimming_pool', false)) AS pool,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'fast_food', false)) AS fast_food,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'restaurant', false)) AS restaurant,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'pub', false)) AS pub,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'bar', false)) AS bar
FROM      osm_poi_poly                               AS poly
LEFT JOIN osm_poi_all                                AS pt
ON        poly.geom && pt.geom
WHERE     ((
                              poly.tags ? 'tourism')
          AND       (
                              poly.tags->'tourism' = 'camp_site'))
-- campsites from OSM ways
          AND (poly.osm_id < 0) AND (poly.osm_id > -1e17)
GROUP BY  poly.osm_id,
          poly.geom,
          poly.tags
UNION ALL
SELECT    (-1*(poly.osm_id+1e17)) AS osm_id,
          poly.geom               AS geom,
-- this will remove the redundant key 'tourism' = 'camp_site' from hstore
          poly.tags - 'tourism'::text - 'type'::text AS tags,
          'relation' as osm_type,
          CASE WHEN poly.tags->'access' IN ('private','members') THEN 'private'
               WHEN poly.tags->'group_only' = 'yes' THEN 'group_only'
               WHEN poly.tags->'backcountry' = 'yes' THEN 'backcountry'
          ELSE 'standard' END AS category,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'toilets', false)) AS toilets,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'shower', false)) AS shower,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'swimming_pool', false)) AS pool,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'fast_food', false)) AS fast_food,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'restaurant', false)) AS restaurant,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'pub', false)) AS pub,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'bar', false)) AS bar
FROM      osm_poi_poly                               AS poly
LEFT JOIN osm_poi_all                                AS pt
ON        poly.geom && pt.geom
WHERE     ((
                              poly.tags ? 'tourism')
          AND       (
                              poly.tags->'tourism' = 'camp_site'))
-- campsites from OSM relations
          AND (poly.osm_id < -1e17)
GROUP BY  poly.osm_id,
          poly.geom,
          poly.tags

UNION ALL
SELECT    osm_id,
          geom,
-- this will remove the redundant key 'tourism' = 'camp_site' from hstore
          tags - 'tourism'::text AS tags,
          'node' as osm_type,
          CASE WHEN tags->'access' IN ('private','members') THEN 'private'
               WHEN tags->'group_only' = 'yes' THEN 'group_only'
               WHEN tags->'backcountry' = 'yes' THEN 'backcountry'
          ELSE 'standard' END AS category,
          CASE WHEN tags->'toilets'='yes' THEN True ELSE False END,
          CASE WHEN tags->'shower'='yes' THEN True ELSE False END,
          CASE WHEN tags->'swimming_pool'='yes' THEN True ELSE False END,
          False,
          False,
          False,
          False
FROM      osm_poi_point          
WHERE     ((
                              tags ? 'tourism')
          AND       (
                              tags->'tourism' = 'camp_site'));

-- geometry index
CREATE INDEX osm_poi_campsite_geom ON osm_poi_campsites USING GIST (geom);
