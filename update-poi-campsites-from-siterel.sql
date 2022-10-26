-- update table osm_poi_campsites based on members of site relations
--
-- (c) 2021 Sven Geggus <sven-osm@geggus-net>
--
-- Changes made here might also need to be added to gen_poi_campsites.sql
--
-- merge tags from site relation itself into tags from related point or polygon
-- tagged as 'tourism'='camp_site'
-- this will prefer the tags from the site relation over the ones from the point or polygon

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
    osm_poi_camp_siterel_extended
  WHERE
    member_tags -> 'tourism' = 'camp_site') sr
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

