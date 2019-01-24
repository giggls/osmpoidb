-- create MATERIALIZED VIEW to be used
-- in json output

CREATE OR REPLACE VIEW osm_poi_all AS
SELECT    osm_id,tags,geom
FROM      osm_poi_poly
UNION ALL
SELECT    osm_id,tags,geom
FROM      osm_poi_point;

DROP MATERIALIZED VIEW IF EXISTS osm_poi_campsites;
CREATE MATERIALIZED VIEW osm_poi_campsites AS
SELECT    (-1*poly.osm_id)      AS osm_id,
          poly.geom             AS geom,
-- this will remove the redundant key 'tourism' = 'camp_site' from hstore
          poly.tags - 'tourism'::text AS tags,
          'way' as osm_type,
          CASE WHEN poly.tags->'access' IN ('private','members') THEN 'private'
               WHEN poly.tags->'nudism' IN ('yes','obligatory','customary','designated') THEN 'nudist'
               WHEN poly.tags->'group_only' = 'yes' THEN 'group_only'
               WHEN poly.tags->'backcountry' = 'yes' THEN 'backcountry'
          ELSE 'standard' END AS category,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'telephone', false)) AS telephone,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'post_box', false)) AS post_box,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'drinking_water', false)) AS drinking_water,
-- any shop likely convenience
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       (pt.tags ? 'shop'), false)) AS shop,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'shop' = 'laundry', false)) AS laundry,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'sanitary_dump_station', false)) AS sanitary_dump_station,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'firepit', false)) AS firepit,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'bbq', false)) AS bbq,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'toilets', false)) AS toilets,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'shower', false)) AS shower,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'playground', false)) AS playground,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'swimming_pool', false)) AS swimming_pool,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'sauna', false)) AS sauna,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'fast_food', false)) AS fast_food,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'restaurant', false)) AS restaurant,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'pub', false)) AS pub,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'bar', false)) AS bar,
-- This will produce a list of available sport facilities on the premises
array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects(poly.geom, pt.geom)
AND       (pt.tags ? 'sport') AND (pt.osm_id != poly.osm_id)) THEN pt.tags->'sport' END),NULL) as sport
FROM      osm_poi_poly                               AS poly
LEFT JOIN osm_poi_all                                AS pt
ON        poly.geom && pt.geom
WHERE     (poly.tags ? 'tourism') AND (poly.tags->'tourism' = 'camp_site')
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
               WHEN poly.tags->'nudism' IN ('yes','obligatory','customary','designated') THEN 'nudist'
               WHEN poly.tags->'group_only' = 'yes' THEN 'group_only'
               WHEN poly.tags->'backcountry' = 'yes' THEN 'backcountry'
          ELSE 'standard' END AS category,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'telephone', false)) AS telephone,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'post_box', false)) AS post_box,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'drinking_water', false)) AS drinking_water,
-- any shop likely convenience
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       (pt.tags ? 'shop'), false)) AS shop,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'shop' = 'laundry', false)) AS laundry,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'sanitary_dump_station', false)) AS sanitary_dump_station,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'firepit', false)) AS firepit,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'bbq', false)) AS bbq,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'toilets', false)) AS toilets,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'shower', false)) AS shower,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'playground', false)) AS playground,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'swimming_pool', false)) AS swimming_pool,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'leisure' = 'sauna', false)) AS sauna,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'fast_food', false)) AS fast_food,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'restaurant', false)) AS restaurant,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'pub', false)) AS pub,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom)
AND       pt.tags->'amenity' = 'bar', false)) AS bar,
-- This will produce a list of available sport facilities on the premises
array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects(poly.geom, pt.geom)
AND       (pt.tags ? 'sport') AND (pt.osm_id != poly.osm_id)) THEN pt.tags->'sport' END),NULL) as sport
FROM      osm_poi_poly                               AS poly
LEFT JOIN osm_poi_all                                AS pt
ON        poly.geom && pt.geom
WHERE     (poly.tags ? 'tourism') AND (poly.tags->'tourism' = 'camp_site')
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
               WHEN tags->'nudism' IN ('yes','obligatory','customary') THEN 'nudist'
               WHEN tags->'group_only' = 'yes' THEN 'group_only'
               WHEN tags->'backcountry' = 'yes' THEN 'backcountry'
          ELSE 'standard' END AS category,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          False,
          '{}'
FROM      osm_poi_point          
WHERE     ((tags ? 'tourism') AND (tags->'tourism' = 'camp_site'));

-- geometry index
CREATE INDEX osm_poi_campsites_geom ON osm_poi_campsites USING GIST (geom);
-- index on osm_id (UNIQUE)
-- This seems to be needed for CONCURRENTLY REFRESH of MATERIALIZED VIEW
CREATE UNIQUE INDEX osm_poi_campsites_osm_id ON osm_poi_campsites (osm_id);


GRANT SELECT ON osm_poi_campsites to public;
