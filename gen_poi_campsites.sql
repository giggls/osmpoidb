-- add or unify addr:country tag
-- make sure country tag is always lowercase
CREATE OR REPLACE FUNCTION unify_tags (tin hstore, geom geometry)
  RETURNS hstore
  AS $$
DECLARE
  out hstore;
  country text;
  tag text[];
BEGIN
  out = tin;
  -- add addr:country if not already available
  IF NOT out ? 'addr:country' THEN
    SELECT
      country_code INTO country
    FROM
      country_osm_grid
    WHERE
      st_contains (geometry, st_centroid (geom));
    IF country IS NOT NULL THEN
      out = out || hstore ('addr:country', country);
    END IF;
  ELSE
     IF (LENGTH(out->'addr:country') = 2) THEN
       out = out || hstore ('addr:country', lower(out->'addr:country'));
     ELSE
       SELECT
         country_code INTO country
       FROM
         country_osm_grid
       WHERE
         st_contains (geometry, st_centroid (geom));
       IF country IS NOT NULL THEN
         out = out || hstore ('addr:country', country);
       END IF;
     END IF;
  END IF;
  RETURN out;
END
$$
LANGUAGE plpgsql;

-- a view to point and polygon shaped POI objects
CREATE OR REPLACE VIEW osm_poi_ptpy AS
SELECT * FROM osm_poi_poly
UNION ALL
SELECT * FROM osm_poi_point;
  
-- a view to all POI objects regardless off their shape
CREATE OR REPLACE VIEW osm_poi_all AS
SELECT * FROM osm_poi_poly
UNION ALL
SELECT * FROM osm_poi_point
UNION ALL
SELECT * FROM osm_poi_line;

CREATE TABLE osm_poi_campsites AS
SELECT
  poly.osm_id AS osm_id,
  poly.geom AS geom,
  unify_tags (poly.tags, poly.geom) AS tags,
  greatest(max(CASE WHEN _st_intersects(poly.geom, pt.geom) THEN pt.timestamp END),poly.timestamp) as timestamp,
  poly.osm_type AS osm_type,
  CASE WHEN poly.tags -> 'nudism' IN ('yes', 'obligatory', 'customary', 'designated') THEN
    'nudist'
  WHEN ((poly.tags -> 'group_only' = 'yes')
    OR (poly.tags -> 'scout' = 'yes')) THEN
    'group_only'
  WHEN poly.tags -> 'backcountry' = 'yes' THEN
    'backcountry'
  WHEN ((poly.tags -> 'tents' = 'yes')
    AND (poly.tags -> 'caravans' = 'no') AND (poly.tags -> 'motorhome' != 'yes')) THEN
    'camping'
  WHEN ((poly.tags -> 'tents' = 'no')
    OR ((poly.tags -> 'tourism' = 'caravan_site')
      AND NOT (poly.tags ? 'tents'))) THEN
    'caravan'
  ELSE
    'standard'
  END AS category,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'telephone', FALSE)) AS telephone,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'post_box', FALSE)) AS post_box,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND ((pt.tags -> 'amenity' = 'drinking_water')
       OR ((pt.tags -> 'man_made' = 'water_tap') AND (pt.tags -> 'drinking_water' = 'yes'))
       OR (pt.tags -> 'amenity' = 'water_point')), FALSE)) AS drinking_water,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'power_supply', FALSE)) AS power_supply,
  -- any shop likely convenience
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND ((pt.tags ? 'shop')
      AND pt.tags -> 'shop' != 'laundry'), FALSE)) AS shop,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND ((pt.tags -> 'amenity' = 'washing_machine')
       OR (pt.tags -> 'shop' = 'laundry')), FALSE)) AS laundry,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'sanitary_dump_station', FALSE)) AS sanitary_dump_station,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'leisure' = 'firepit', FALSE)) AS firepit,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'bbq', FALSE)) AS bbq,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'toilets', FALSE)) AS toilets,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND ((pt.tags -> 'amenity' = 'shower')
       OR ((pt.tags -> 'amenity' = 'toilets')
      AND (pt.tags ? 'shower')
      AND (pt.tags -> 'shower' != 'no'))), FALSE)) AS shower,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'leisure' = 'playground', FALSE)) AS playground,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'leisure' = 'swimming_pool', FALSE)) AS swimming_pool,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'leisure' = 'golf_course', FALSE)) AS golf_course,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'leisure' = 'miniature_golf', FALSE)) AS miniature_golf,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'leisure' = 'sauna', FALSE)) AS sauna,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'fast_food', FALSE)) AS fast_food,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'restaurant', FALSE)) AS restaurant,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'pub', FALSE)) AS pub,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'bar', FALSE)) AS bar,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'building' = 'cabin', FALSE)) AS cabin,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'building' = 'static_caravan', FALSE)) AS static_caravan,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'amenity' = 'kitchen', FALSE)) AS kitchen,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND ((pt.tags -> 'amenity' = 'sink')
       OR ((pt.tags -> 'amenity' = 'kitchen')
      AND (pt.tags ? 'sink')
      AND (pt.tags -> 'sink' != 'no'))), FALSE)) AS sink,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND ((pt.tags -> 'amenity' = 'fridge')
       OR ((pt.tags -> 'amenity' = 'kitchen')
      AND (pt.tags ? 'fridge')
      AND (pt.tags -> 'fridge' != 'no'))), FALSE)) AS fridge,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'leisure' = 'picnic_table', FALSE)) AS picnic_table,
  -- This will produce a list of available sport facilities on the premises
  array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects (poly.geom, pt.geom)
        AND (pt.tags ? 'sport')
        AND (pt.osm_id != poly.osm_id)) THEN
        pt.tags -> 'sport'
      END), NULL) AS sport,
  TRUE as visible
FROM
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_ptpy AS pt ON poly.geom && pt.geom
WHERE (poly.tags ? 'tourism')
AND (poly.tags -> 'tourism' IN ('camp_site', 'caravan_site'))
GROUP BY
  poly.osm_id,
  poly.osm_type,
  poly.geom,
  poly.tags,
  poly.timestamp
UNION ALL
SELECT
  osm_id,
  geom,
  -- this will remove the redundant key 'tourism' = 'camp_site' from hstore
  unify_tags (tags, geom) AS tags,
  timestamp,
  osm_type,
  CASE WHEN tags -> 'nudism' IN ('yes', 'obligatory', 'customary', 'designated') THEN
    'nudist'
  WHEN ((tags -> 'group_only' = 'yes')
    OR (tags -> 'scout' = 'yes')) THEN
    'group_only'
  WHEN tags -> 'backcountry' = 'yes' THEN
    'backcountry'
  WHEN ((tags -> 'tents' = 'yes')
    AND (tags -> 'caravans' = 'no')) THEN
    'camping'
  WHEN ((tags -> 'tents' = 'no')
    OR ((tags -> 'tourism' = 'caravan_site')
      AND NOT (tags ? 'tents'))) THEN
    'caravan'
  ELSE
    'standard'
  END AS category,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  '{}',
  TRUE
FROM
  osm_poi_point
WHERE (tags ? 'tourism')
AND (tags -> 'tourism' IN ('camp_site', 'caravan_site'));

-- geometry index
CREATE INDEX osm_poi_campsites_geom ON osm_poi_campsites USING GIST (geom);

-- index on osm_id (UNIQUE) maybe not needed
--CREATE UNIQUE INDEX osm_poi_campsites_osm_id ON osm_poi_campsites (id);

-- index on osm_type
CREATE INDEX osm_poi_campsites_osm_type ON osm_poi_campsites (osm_type);

GRANT SELECT ON osm_poi_campsites TO public;

-- extend osm_poi_camp_siterel with geometry and member tags
CREATE OR REPLACE VIEW osm_poi_camp_siterel_extended AS
SELECT
  pa.geom,
  pa.tags AS member_tags,
  sr.*
FROM
  osm_poi_camp_siterel sr
  JOIN osm_poi_all pa ON sr.member_type=pa.osm_type AND sr.member_id=pa.osm_id;
