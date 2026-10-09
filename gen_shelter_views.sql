-- A materialized view is sufficient for shelters
-- as we currently need no poi in poi feature

DROP VIEW IF EXISTS osm_poi_campsites_and_shelter;
DROP MATERIALIZED VIEW IF EXISTS osm_poi_shelter;

CREATE MATERIALIZED view osm_poi_shelter AS
SELECT osm_id, geom, tags, timestamp, osm_type from osm_poi_all
WHERE ((tags ? 'amenity') AND  tags ->> 'amenity' = 'shelter'
AND tags ->> 'shelter_type' in ('basic_hut', 'lean_to')
AND (NOT (tags ? 'sleeping') OR (tags ->> 'sleeping' != 'no')) OR
(tags ? 'tourism') AND (tags ->> 'tourism' = 'wilderness_hut'))
AND NOT EXISTS (
    SELECT 1
    FROM osm_poi_campsites c
    WHERE ST_Intersects(osm_poi_all.geom, c.geom)
    AND ST_GeometryType(c.geom) = 'ST_MultiPolygon');

CREATE VIEW osm_poi_campsites_and_shelter AS
SELECT * from osm_poi_campsites
UNION ALL
SELECT
  osm_id,
  geom,
  unify_tags(tags, geom) AS tags,
  timestamp,
  osm_type,
  'shelter',
  FALSE AS telephone,
  FALSE AS post_box,
  FALSE AS drinking_water,
  FALSE AS power_supply,
  FALSE AS shop,
  FALSE AS laundry,
  ARRAY[]::text[] AS sanitary_dump_station,
  FALSE AS firepit,
  FALSE AS bbq,
  FALSE AS toilets,
  FALSE AS playground,
  FALSE AS swimming_pool,
  FALSE AS golf_course,
  FALSE AS miniature_golf,
  FALSE AS bowling_alley,
  FALSE AS sauna,
  FALSE AS fast_food,
  FALSE AS restaurant,
  FALSE AS pub,
  FALSE AS bar,
  FALSE AS cabin,
  FALSE AS static_caravan,
  FALSE AS shelter,
  FALSE AS kitchen,
  FALSE AS sink,
  FALSE AS fridge,
  FALSE AS picnic_table,
  CASE
    WHEN (tags ->> 'shower' = 'hot') THEN 'hot'::showertype
    WHEN (tags ->> 'shower' = 'cold') THEN 'cold'::showertype
    WHEN (tags ->> 'shower' = 'yes') THEN 'yes'::showertype
    WHEN (tags ->> 'shower' = 'outdoor') THEN 'yes'::showertype
    WHEN (tags ->> 'shower' = 'no') THEN 'no'::showertype
    ELSE 'untagged'::showertype
  END AS shower,
  '{}' AS sport,
  TRUE
FROM osm_poi_shelter;
