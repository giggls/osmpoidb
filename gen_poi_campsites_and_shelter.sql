-- Shelter table is currently generated directly from osm2pgsql
-- as we currently need no poi in poi feature

CREATE VIEW osm_poi_campsites_and_shelter AS
SELECT * from osm_poi_campsites
UNION ALL
SELECT
  osm_id,
  geom,
  tags,
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

GRANT SELECT ON ALL TABLES IN SCHEMA public TO public;

-- remove shelters located inside camp_site or caravan_site polygons
-- this also needs to be called in post-update.sql
DELETE from osm_poi_shelter s
WHERE dirty
AND EXISTS (
  SELECT 1
  FROM osm_poi_campsites c
  WHERE ST_Intersects(s.geom, c.geom)
  AND c.osm_type != 'N'
);
UPDATE osm_poi_shelter SET dirty=false WHERE dirty;
