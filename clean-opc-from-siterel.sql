--
-- remove all sites from osm_poi_campsites which are referenced in osm_poi_camp_siterel
-- and re-add them from osm_poi_poly and osm_poi_point in their initial form.
--
-- This is needed as site relations might have gotten added updated or deleted
--
-- Afterwards we just run update-poi-campsites-from-siterel.sql again (for now)

BEGIN;
DELETE FROM osm_poi_campsites
USING osm_poi_camp_siterel
WHERE osm_poi_campsites.osm_id = osm_poi_camp_siterel.member_id
AND osm_poi_campsites.osm_type = osm_poi_camp_siterel.member_type;

INSERT INTO osm_poi_campsites
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
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'building' = 'cabin', FALSE)) AS cabin,
  Bool_or(COALESCE(_st_intersects (poly.geom, pt.geom)
      AND pt.tags -> 'building' = 'static_caravan', FALSE)) AS static_caravan,
  -- This will produce a list of available sport facilities on the premises
  array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects (poly.geom, pt.geom)
        AND (pt.tags ? 'sport')
        AND (pt.osm_id != poly.osm_id)) THEN
        pt.tags -> 'sport'
      END), NULL) AS sport
FROM
  osm_poi_camp_siterel sre,
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_ptpy AS pt ON poly.geom && pt.geom
WHERE
  poly.osm_id=sre.member_id AND poly.osm_type=sre.member_type AND
  (poly.tags ? 'tourism') AND (poly.tags -> 'tourism' IN ('camp_site', 'caravan_site'))
GROUP BY
  poly.osm_id,
  poly.osm_type,
  poly.geom,
  poly.tags,
  poly.timestamp
UNION ALL
SELECT
  pp.osm_id,
  pp.geom,
  -- this will remove the redundant key 'tourism' = 'camp_site' from hstore
  unify_tags (pp.tags, pp.geom) AS tags,
  pp.timestamp,
  pp.osm_type,
  CASE WHEN pp.tags -> 'nudism' IN ('yes', 'obligatory', 'customary', 'designated') THEN
    'nudist'
  WHEN ((pp.tags -> 'group_only' = 'yes')
    OR (pp.tags -> 'scout' = 'yes')) THEN
    'group_only'
  WHEN pp.tags -> 'backcountry' = 'yes' THEN
    'backcountry'
  WHEN ((pp.tags -> 'tents' = 'yes')
    AND (pp.tags -> 'caravans' = 'no')) THEN
    'camping'
  WHEN ((pp.tags -> 'tents' = 'no')
    OR ((pp.tags -> 'tourism' = 'caravan_site')
      AND NOT (pp.tags ? 'tents'))) THEN
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
  '{}'
FROM
  osm_poi_camp_siterel sre,
  osm_poi_point pp
WHERE
  pp.osm_id=sre.member_id AND pp.osm_type=sre.member_type AND
  (pp.tags ? 'tourism') AND (pp.tags -> 'tourism' IN ('camp_site', 'caravan_site'));
COMMIT;

