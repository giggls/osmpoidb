-- Post update stuff for TABLE osm_poi_campsites

-- This will insert all campsites which are affected by other POI updates
-- which are located inside their site area
INSERT INTO osm_todo_campsites(osm_id,osm_type,is_cs)
SELECT pa.osm_id,pa.osm_type,true
FROM osm_poi_all pa,
(
SELECT pa.osm_type,pa.osm_id,pa.geom
FROM osm_poi_all pa
JOIN osm_todo_campsites tc
ON tc.osm_id=pa.osm_id AND tc.osm_type=pa.osm_type
WHERE tc.is_cs=false
) as tc
WHERE (pa.tags -> 'tourism' IN ('camp_site', 'caravan_site'))
AND ST_Intersects(tc.geom,pa.geom)
ON CONFLICT (osm_id,osm_type) DO NOTHING;

-- processing of non campsite objects is done at this stage,
-- thus delete them
DELETE FROM osm_todo_campsites WHERE is_cs=false;

-- This will add all campsites where an internal POI has been deleted
-- The delete trigger function has added them to osm_todo_cs_trigger
INSERT INTO osm_todo_campsites(osm_id,osm_type,is_cs)
SELECT osm_id,osm_type,true
FROM osm_todo_cs_trigger
ON CONFLICT (osm_id,osm_type) DO NOTHING;

-- This will insert all campsites which are affected by POI updates
-- which are members of a NEW camp_site site-relation
-- Modified camp_site site-relations have been already added via delete trigger
INSERT INTO osm_todo_campsites(osm_id,osm_type,is_cs)
SELECT DISTINCT csre.member_id,csre.member_type,true
FROM osm_poi_camp_siterel_extended csre,osm_todo_camp_siterel tcsr
WHERE csre.site_id=tcsr.osm_id
AND csre.member_tags->'tourism' IN ('camp_site', 'caravan_site')
ON CONFLICT (osm_id,osm_type) DO NOTHING;

-- Make osm_id in table osm_todo_camp_siterel UNIQUE
DELETE FROM osm_todo_camp_siterel a USING osm_todo_camp_siterel b WHERE a.id < b.id AND a.osm_id = b.osm_id;

BEGIN;
DELETE FROM osm_poi_campsites
USING osm_todo_campsites
WHERE osm_poi_campsites.osm_id = osm_todo_campsites.osm_id
AND osm_poi_campsites.osm_type = osm_todo_campsites.osm_type;

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
    AND (poly.tags -> 'caravans' = 'no')
    AND (NOT (poly.tags ? 'motorhome') OR (poly.tags -> 'motorhome' != 'yes'))) THEN
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
      AND ((pt.tags -> 'amenity' = 'bbq')
       OR ((pt.tags -> 'leisure' = 'firepit')
      AND (pt.tags ? 'grate')
      AND (pt.tags -> 'grate' = 'yes'))), FALSE)) AS bbq,
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
  osm_todo_campsites tc,
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_ptpy AS pt ON poly.geom && pt.geom
WHERE
  poly.osm_id=tc.osm_id AND poly.osm_type=tc.osm_type
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
    AND (pp.tags -> 'caravans' = 'no')
    AND (NOT (pp.tags ? 'motorhome') OR (pp.tags -> 'motorhome' != 'yes'))) THEN
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
  FALSE,
  FALSE,
  FALSE,
  FALSE,
  '{}',
  TRUE
FROM
  osm_todo_campsites tc,
  osm_poi_point pp
WHERE pp.osm_id=tc.osm_id AND pp.osm_type=tc.osm_type;

-- Now we also need to update those sites which are part of a new or modified site relation
UPDATE
  osm_poi_campsites cs
SET
  -- ignore addr:country from site relation
  tags = cs.tags || (sr.site_tags - 'type'::text - 'site'::text - 'addr:country'::text)
FROM (
  SELECT
    member_id,
    member_type,
    site_tags
  FROM
    osm_poi_camp_siterel_extended csre, osm_todo_camp_siterel tdsr
  WHERE
    member_tags -> 'tourism' = 'camp_site' AND csre.site_id=tdsr.osm_id
     ) sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- telephone in site relations
UPDATE
  osm_poi_campsites cs
SET
  telephone = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'telephone') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- post_box in site relations
UPDATE
  osm_poi_campsites cs
SET
  post_box = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'post_box') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- drinking_water in site relations
UPDATE
  osm_poi_campsites cs
SET
  drinking_water = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'drinking_water') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- any shop (likely convenience) in site relations
UPDATE
  osm_poi_campsites cs
SET
  shop = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND (r.member_tags ? 'shop'
        AND r.member_tags -> 'shop' != 'laundry')) sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- laundry or washing machine in site relations
UPDATE
  osm_poi_campsites cs
SET
  laundry = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND ((r.member_tags -> 'amenity' = 'washing_machine')
        OR (r.member_tags -> 'shop' = 'laundry'))) sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- sanitary_dump_station in site relations
UPDATE
  osm_poi_campsites cs
SET
  sanitary_dump_station = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'sanitary_dump_station') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- firepit in site relations
UPDATE
  osm_poi_campsites cs
SET
  firepit = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'leisure' = 'firepit') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- bbq in site relations
UPDATE
  osm_poi_campsites cs
SET
  bbq = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'bbq') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- toilets in site relations
UPDATE
  osm_poi_campsites cs
SET
  toilets = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'toilets') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- showers or toilets with shower != 'no' in site relations
UPDATE
  osm_poi_campsites cs
SET
  shower = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND ((r.member_tags -> 'amenity' = 'shower')
        OR ((r.member_tags -> 'amenity' = 'toilets')
          AND (r.member_tags ? 'shower')
          AND (r.member_tags -> 'shower' != 'no')))) sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- playground in site relations
UPDATE
  osm_poi_campsites cs
SET
  playground = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'leisure' = 'playground') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- swimming_pool in site relations
UPDATE
  osm_poi_campsites cs
SET
  swimming_pool = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'leisure' = 'swimming_pool') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- golf_course in site relations
UPDATE
  osm_poi_campsites cs
SET
  golf_course = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'leisure' = 'golf_course') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- miniature_golf in site relations
UPDATE
  osm_poi_campsites cs
SET
  miniature_golf = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'leisure' = 'miniature_golf') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- sauna in site relations
UPDATE
  osm_poi_campsites cs
SET
  sauna = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'leisure' = 'sauna') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- fast_food in site relations
UPDATE
  osm_poi_campsites cs
SET
  fast_food = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'fast_food') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- restaurant in site relations
UPDATE
  osm_poi_campsites cs
SET
  restaurant = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'restaurant') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- pub in site relations
UPDATE
  osm_poi_campsites cs
SET
  pub = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'pub') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- bar in site relations
UPDATE
  osm_poi_campsites cs
SET
  bar = TRUE
FROM (
  SELECT
    s.member_id,
    s.member_type
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags -> 'amenity' = 'bar') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- sports facilities in site relations
UPDATE
  osm_poi_campsites cs
SET
  sport = ARRAY ( SELECT DISTINCT
      UNNEST(cs.sport || sr.sport))
FROM (
  SELECT
    s.member_id,
    s.member_type,
    array_agg(r.member_tags -> 'sport') AS sport
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND r.member_tags ? 'sport'
  GROUP BY
    s.member_id,
    s.member_type) sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- Add site relation URL to member campsites
UPDATE
  osm_poi_campsites cs
SET
  -- This will overwrite the site_relation value with the latter one,
  -- if the site is a member of more than one site relation
  tags = tags || hstore ('site_relation', sr.site_id::text)
FROM (
  SELECT
    member_id,
    member_type,
    site_id
  FROM
    osm_poi_camp_siterel_extended
  WHERE
    member_tags -> 'tourism' = 'camp_site') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- Mark campsites which are members of an invalid site relation
-- with more than one member tagged 'tourism' = 'camp_site'
UPDATE
  osm_poi_campsites cs
SET
  tags = tags || hstore ('site_relation_state', 'invalid')
FROM (
  SELECT
    member_id,
    member_type
  FROM
    osm_poi_camp_siterel_extended
  WHERE
    site_id IN (
      SELECT
        site_id
      FROM (
        SELECT
          site_id,
          count(*)
        FROM
          osm_poi_camp_siterel_extended
        WHERE
          member_tags -> 'tourism' = 'camp_site'
        GROUP BY
          site_id) AS c
      WHERE
        COUNT != 1)
      AND member_tags -> 'tourism' = 'camp_site') sr
WHERE
  cs.osm_id = sr.member_id
  AND cs.osm_type = sr.member_type;

-- Mark campsites which are members of a redundant site relation
-- with all POI objects inside the 'tourism' = 'camp_site' polygon
UPDATE
  osm_poi_campsites cs
SET
  tags = tags || hstore ('site_relation_state', 'useless')
FROM (
  SELECT
    s.member_id,
    bool_and(st_within (r.geom, s.geom)) AS WITHIN
  FROM
    osm_poi_camp_siterel_extended s
    INNER JOIN osm_poi_camp_siterel_extended r ON s.site_id = r.site_id
      AND s.member_tags -> 'tourism' = 'camp_site'
      AND ((r.member_tags -> 'tourism' != 'camp_site')
        OR NOT (r.member_tags ? 'tourism'))
      GROUP BY
        s.member_id) sr
WHERE
  sr.within = TRUE
  AND cs.osm_id = sr.member_id;





COMMIT;

DELETE FROM osm_todo_campsites;
DELETE FROM osm_todo_cs_trigger;
DELETE FROM osm_todo_camp_siterel;


-- Post update stuff for TABLE osm_poi_playgrounds

-- This will insert all playgrounds which are affected by other POI updates
INSERT INTO osm_todo_playgrounds(osm_id,osm_type,is_pg)
SELECT pa.osm_id,pa.osm_type,true
FROM osm_poi_all pa,
(
SELECT pa.osm_type,pa.osm_id,pa.geom
FROM osm_poi_all pa
JOIN osm_todo_playgrounds tp
ON tp.osm_id=pa.osm_id AND tp.osm_type=pa.osm_type
WHERE tp.is_pg=false
) as tp
WHERE (pa.tags -> 'leisure' = 'playground')
AND ST_Intersects(tp.geom,pa.geom)
ON CONFLICT (osm_id,osm_type) DO NOTHING;

DELETE FROM osm_todo_playgrounds WHERE is_pg=false;

INSERT INTO osm_todo_playgrounds(osm_id,osm_type,is_pg)
SELECT osm_id,osm_type,true
FROM osm_todo_pg_trigger
ON CONFLICT (osm_id,osm_type) DO NOTHING;

BEGIN;
DELETE FROM osm_poi_playgrounds
USING osm_todo_playgrounds
WHERE osm_poi_playgrounds.osm_id = osm_todo_playgrounds.osm_id
AND osm_poi_playgrounds.osm_type = osm_todo_playgrounds.osm_type;

INSERT INTO osm_poi_playgrounds
SELECT
  poly.osm_id AS osm_id,
  poly.osm_type AS osm_type,
  poly.tags AS tags,
  greatest(max(CASE WHEN _st_intersects(poly.geom, pt.geom) THEN pt.timestamp END),poly.timestamp) as timestamp,
  poly.geom AS geom,
  -- This will produce a list of available playground facilities on the premises
  array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects (poly.geom, pt.geom)
        AND (pt.tags ? 'playground')
        AND (pt.osm_id != poly.osm_id)) THEN
        pt.tags -> 'playground'
      END), NULL) AS equipment,
  -- This will produce a list of available sport facilities on the premises
  array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects (poly.geom, pt.geom)
        AND (pt.tags ? 'sport')
        AND (pt.osm_id != poly.osm_id)) THEN
        pt.tags -> 'sport'
      END), NULL) AS sport
FROM
  osm_todo_playgrounds tp,
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_ptpy AS pt ON poly.geom && pt.geom
WHERE
  poly.osm_id=tp.osm_id AND poly.osm_type=tp.osm_type
GROUP BY
  poly.osm_id,
  poly.osm_type,
  poly.tags,
  poly.timestamp,
  poly.geom
UNION ALL
SELECT
  pp.osm_id,
  pp.osm_type,
  pp.tags,
  pp.timestamp,
  pp.geom,
  '{}',
  '{}'
FROM
  osm_todo_playgrounds tp,
  osm_poi_point pp
WHERE pp.osm_id=tp.osm_id AND pp.osm_type=tp.osm_type;
COMMIT;

DELETE FROM osm_todo_playgrounds;
DELETE FROM osm_todo_pg_trigger;
