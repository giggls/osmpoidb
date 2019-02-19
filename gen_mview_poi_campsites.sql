-- unification function fo inconsistent tagging
-- exchange keys according to mapping

CREATE OR REPLACE FUNCTION
unify_tags(tin hstore) returns hstore as $$
DECLARE
 out hstore;
 tag text[];
 mapping CONSTANT text[][] := '{{booking,reservation},
                                {contact:phone,phone},
                                {contact:fax,fax},
                                {contact:website,website},
                                {contact:email,email},
                                {url,website}}';
BEGIN
  out = tin;
  FOREACH tag SLICE 1 IN ARRAY mapping
  LOOP
    IF tin ? tag[1] THEN
      out = (out - tag[1]) || hstore(tag[2], out -> tag[1]);
    END IF;
  END LOOP;
  RETURN out;
END
$$ language plpgsql;

-- create MATERIALIZED VIEW to be used
-- in json output

CREATE OR REPLACE VIEW osm_poi_all AS
SELECT    osm_id,tags,geom
FROM      osm_poi_poly
UNION ALL
SELECT    osm_id,tags,geom
FROM      osm_poi_point;


CREATE MATERIALIZED VIEW osm_poi_campsites_tmp AS
SELECT    (-1*poly.osm_id)      AS osm_id,
          poly.geom             AS geom,
-- this will remove the redundant key 'tourism' = 'camp_site' from hstore
          unify_tags(poly.tags) AS tags,
          'way' as osm_type,
          CASE WHEN poly.tags->'nudism' IN ('yes','obligatory','customary','designated') THEN 'nudist'
               WHEN poly.tags->'group_only' = 'yes' THEN 'group_only'
               WHEN poly.tags->'backcountry' = 'yes' THEN 'backcountry'
               WHEN ((poly.tags->'tents' = 'yes') AND (poly.tags->'caravans' = 'no')) THEN 'camping'
               WHEN ((poly.tags->'tents' = 'no') OR ( (poly.tags->'tourism' = 'caravan_site') AND NOT (poly.tags ? 'tents'))) THEN 'caravan'
          ELSE 'standard' END AS category,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'telephone', false)) AS telephone,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'post_box', false)) AS post_box,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'drinking_water', false)) AS drinking_water,
-- any shop likely convenience
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND (pt.tags ? 'shop'), false)) AS shop,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND ((pt.tags->'amenity' = 'washing_machine') OR (pt.tags->'shop' = 'laundry')), false)) AS laundry,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'sanitary_dump_station', false)) AS sanitary_dump_station,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'firepit', false)) AS firepit,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'bbq', false)) AS bbq,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'toilets', false)) AS toilets,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND ((pt.tags->'amenity' = 'shower') OR ((pt.tags->'amenity' = 'toilets') AND (pt.tags->'shower' = 'yes'))), false)) AS shower,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'playground', false)) AS playground,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'swimming_pool', false)) AS swimming_pool,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'sauna', false)) AS sauna,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'fast_food', false)) AS fast_food,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'restaurant', false)) AS restaurant,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'pub', false)) AS pub,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'bar', false)) AS bar,
-- This will produce a list of available sport facilities on the premises
array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects(poly.geom, pt.geom) AND (pt.tags ? 'sport') AND (pt.osm_id != poly.osm_id)) THEN pt.tags->'sport' END),NULL) as sport
FROM      osm_poi_poly                               AS poly
LEFT JOIN osm_poi_all                                AS pt
ON        poly.geom && pt.geom
WHERE     (poly.tags ? 'tourism') AND (poly.tags->'tourism' in ('camp_site','caravan_site'))
-- campsites from OSM ways
          AND (poly.osm_id < 0) AND (poly.osm_id > -1e17)
GROUP BY  poly.osm_id,
          poly.geom,
          poly.tags
UNION ALL
SELECT    (-1*(poly.osm_id+1e17)) AS osm_id,
          poly.geom               AS geom,
-- this will remove the redundant key 'tourism' = 'camp_site' from hstore
          unify_tags(poly.tags) AS tags,
          'relation' as osm_type,
          CASE WHEN poly.tags->'nudism' IN ('yes','obligatory','customary','designated') THEN 'nudist'
               WHEN poly.tags->'group_only' = 'yes' THEN 'group_only'
               WHEN poly.tags->'backcountry' = 'yes' THEN 'backcountry'
               WHEN ((poly.tags->'tents' = 'yes') AND (poly.tags->'caravans' = 'no')) THEN 'camping'
               WHEN ((poly.tags->'tents' = 'no') OR ( (poly.tags->'tourism' = 'caravan_site') AND NOT (poly.tags ? 'tents'))) THEN 'caravan'
          ELSE 'standard' END AS category,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'telephone', false)) AS telephone,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'post_box', false)) AS post_box,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'drinking_water', false)) AS drinking_water,
-- any shop likely convenience
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND (pt.tags ? 'shop'), false)) AS shop,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND ((pt.tags->'amenity' = 'washing_machine') OR (pt.tags->'shop' = 'laundry')), false)) AS laundry,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'sanitary_dump_station', false)) AS sanitary_dump_station,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'firepit', false)) AS firepit,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'bbq', false)) AS bbq,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'toilets', false)) AS toilets,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND ((pt.tags->'amenity' = 'shower') OR ((pt.tags->'amenity' = 'toilets') AND (pt.tags->'shower' = 'yes'))), false)) AS shower,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'playground', false)) AS playground,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'swimming_pool', false)) AS swimming_pool,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'leisure' = 'sauna', false)) AS sauna,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'fast_food', false)) AS fast_food,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'restaurant', false)) AS restaurant,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'pub', false)) AS pub,
          Bool_or(COALESCE(_st_intersects(poly.geom, pt.geom) AND pt.tags->'amenity' = 'bar', false)) AS bar,
-- This will produce a list of available sport facilities on the premises
array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects(poly.geom, pt.geom)
AND       (pt.tags ? 'sport') AND (pt.osm_id != poly.osm_id)) THEN pt.tags->'sport' END),NULL) as sport
FROM      osm_poi_poly                               AS poly
LEFT JOIN osm_poi_all                                AS pt
ON        poly.geom && pt.geom
WHERE     (poly.tags ? 'tourism') AND (poly.tags->'tourism' in ('camp_site','caravan_site'))
-- campsites from OSM relations
          AND (poly.osm_id < -1e17)
GROUP BY  poly.osm_id,
          poly.geom,
          poly.tags

UNION ALL
SELECT    osm_id,
          geom,
-- this will remove the redundant key 'tourism' = 'camp_site' from hstore
          unify_tags(tags) AS tags,
          'node' as osm_type,
          CASE WHEN tags->'nudism' IN ('yes','obligatory','customary','designated') THEN 'nudist'
               WHEN tags->'group_only' = 'yes' THEN 'group_only'
               WHEN tags->'backcountry' = 'yes' THEN 'backcountry'
               WHEN ((tags->'tents' = 'yes') AND (tags->'caravans' = 'no')) THEN 'camping'
               WHEN ((tags->'tents' = 'no') OR ( (tags->'tourism' = 'caravan_site') AND NOT (tags ? 'tents'))) THEN 'caravan'
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
WHERE     (tags ? 'tourism') AND (tags->'tourism' in ('camp_site','caravan_site'));

-- geometry index
CREATE INDEX osm_poi_campsites_geom_tmp ON osm_poi_campsites_tmp USING GIST (geom);
-- index on osm_id (UNIQUE)
-- This seems to be needed for CONCURRENTLY REFRESH of MATERIALIZED VIEW
CREATE UNIQUE INDEX osm_poi_campsites_osm_id_tmp ON osm_poi_campsites_tmp (osm_id);

-- this is hopefully atomic enough for a production setup
DROP MATERIALIZED VIEW osm_poi_campsites;
ALTER MATERIALIZED VIEW osm_poi_campsites_tmp RENAME TO osm_poi_campsites;
ALTER INDEX osm_poi_campsites_geom_tmp RENAME TO osm_poi_campsites_geom;
ALTER INDEX osm_poi_campsites_osm_id_tmp RENAME TO osm_poi_campsites_osm_id;

GRANT SELECT ON osm_poi_campsites to public;
