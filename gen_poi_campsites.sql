-- unification function for inconsistent tagging
-- exchange keys according to mapping
CREATE OR REPLACE FUNCTION unify_tags (tin hstore, geom geometry)
  RETURNS hstore
  AS $$
DECLARE
  out hstore;
  country text;
  tag text[];
  MAPPING CONSTANT text[][] := '{{booking,reservation},
                                {contact:phone,phone},
                                {contact:fax,fax},
                                {contact:website,website},
                                {contact:email,email},
                                {url,website}}';
BEGIN
  out = tin;
  FOREACH tag SLICE 1 IN ARRAY MAPPING LOOP
    IF tin ? tag[1] THEN
      out = (out - tag[1]) || hstore (tag[2], out -> tag[1]);
    END IF;
  END LOOP;
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
  END IF;
  RETURN out;
END
$$
LANGUAGE plpgsql;

-- create Table to be used
-- in json output
CREATE OR REPLACE VIEW osm_poi_ptpy AS
SELECT
  osm_id,
  tags,
  geom
FROM
  osm_poi_poly
UNION ALL
SELECT
  osm_id,
  tags,
  geom
FROM
  osm_poi_point;

CREATE TABLE osm_poi_campsites_tmp AS
SELECT
  poly.osm_id AS id,
  (-1 * poly.osm_id) AS osm_id,
  poly.geom AS geom,
  -- this will remove the redundant key 'tourism' = 'camp_site' from hstore
  unify_tags (poly.tags, poly.geom) AS tags,
  'way' AS osm_type,
  CASE WHEN poly.tags -> 'nudism' IN ('yes', 'obligatory', 'customary', 'designated') THEN
    'nudist'
  WHEN ((poly.tags -> 'group_only' = 'yes')
    OR (poly.tags -> 'scout' = 'yes')) THEN
    'group_only'
  WHEN poly.tags -> 'backcountry' = 'yes' THEN
    'backcountry'
  WHEN ((poly.tags -> 'tents' = 'yes')
    AND (poly.tags -> 'caravans' = 'no')) THEN
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
  -- This will produce a list of available sport facilities on the premises
  array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects (poly.geom, pt.geom)
        AND (pt.tags ? 'sport')
        AND (pt.osm_id != poly.osm_id)) THEN
        pt.tags -> 'sport'
      END), NULL) AS sport
FROM
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_ptpy AS pt ON poly.geom && pt.geom
WHERE (poly.tags ? 'tourism')
AND (poly.tags -> 'tourism' IN ('camp_site', 'caravan_site'))
-- campsites from OSM ways
AND (poly.osm_id < 0)
AND (poly.osm_id > - 1e17)
GROUP BY
  poly.osm_id,
  poly.geom,
  poly.tags
UNION ALL
SELECT
  poly.osm_id AS id,
  (-1 * (poly.osm_id + 1e17)) AS osm_id,
  poly.geom AS geom,
  -- this will remove the redundant key 'tourism' = 'camp_site' from hstore
  unify_tags (poly.tags, poly.geom) AS tags,
  'relation' AS osm_type,
  CASE WHEN poly.tags -> 'nudism' IN ('yes', 'obligatory', 'customary', 'designated') THEN
    'nudist'
  WHEN ((poly.tags -> 'group_only' = 'yes')
    OR (poly.tags -> 'scout' = 'yes')) THEN
    'group_only'
  WHEN poly.tags -> 'backcountry' = 'yes' THEN
    'backcountry'
  WHEN ((poly.tags -> 'tents' = 'yes')
    AND (poly.tags -> 'caravans' = 'no')) THEN
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
      AND (pt.tags ? 'shop'), FALSE)) AS shop,
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
  -- This will produce a list of available sport facilities on the premises
  array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects (poly.geom, pt.geom)
        AND (pt.tags ? 'sport')
        AND (pt.osm_id != poly.osm_id)) THEN
        pt.tags -> 'sport'
      END), NULL) AS sport
FROM
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_ptpy AS pt ON poly.geom && pt.geom
WHERE (poly.tags ? 'tourism')
AND (poly.tags -> 'tourism' IN ('camp_site', 'caravan_site'))
-- campsites from OSM relations
AND (poly.osm_id < - 1e17)
GROUP BY
  poly.osm_id,
  poly.geom,
  poly.tags
UNION ALL
SELECT
  osm_id AS id,
  osm_id,
  geom,
  -- this will remove the redundant key 'tourism' = 'camp_site' from hstore
  unify_tags (tags, geom) AS tags,
  'node' AS osm_type,
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
  '{}'
FROM
  osm_poi_point
WHERE (tags ? 'tourism')
AND (tags -> 'tourism' IN ('camp_site', 'caravan_site'));

-- geometry index
CREATE INDEX osm_poi_campsites_geom_tmp ON osm_poi_campsites_tmp USING GIST (geom);

-- index on osm_id (UNIQUE) maybe not needed
CREATE UNIQUE INDEX osm_poi_campsites_osm_id_tmp ON osm_poi_campsites_tmp (id);

-- index on osm_type
CREATE INDEX osm_poi_campsites_osm_type_tmp ON osm_poi_campsites_tmp (osm_type);

GRANT SELECT ON osm_poi_campsites_tmp TO public;

-- this is hopefully atomic enough for a production setup
BEGIN;
DROP TABLE IF EXISTS osm_poi_campsites;
ALTER TABLE osm_poi_campsites_tmp RENAME TO osm_poi_campsites;
ALTER INDEX osm_poi_campsites_geom_tmp RENAME TO osm_poi_campsites_geom;
ALTER INDEX osm_poi_campsites_osm_id_tmp RENAME TO osm_poi_campsites_osm_id;
ALTER INDEX osm_poi_campsites_osm_type_tmp RENAME TO osm_poi_campsites_osm_type;
COMMIT;

CREATE OR REPLACE FUNCTION imposm_type2uniqe_id (member_id bigint, imposm_type smallint)
  RETURNS bigint
  AS $$
BEGIN
  IF imposm_type = 2 THEN
    RETURN (-1 * (member_id + 1e17));
  END IF;
  IF imposm_type = 1 THEN
    RETURN (-1 * member_id);
  ELSE
    RETURN member_id;
  END IF;
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE VIEW osm_poi_camp_siterel_unique AS
SELECT
  imposm_type2uniqe_id (member_id, osm_type) AS unique_member_id,
  *
FROM
  osm_poi_camp_siterel;

CREATE OR REPLACE VIEW osm_poi_camp_siterel_with_geom AS
SELECT
  p.geom,
  s.*
FROM
  osm_poi_camp_siterel_unique s
  INNER JOIN osm_poi_ptpy p ON p.osm_id = s.unique_member_id;

