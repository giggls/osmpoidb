-- update osm_poi_campsites with obvious bugs to display them on Open Camping Map
--
-- (c) 2022 Sven Geggus <sven-osm@geggus-net>
--
-- tourism=camp_site objects inside tourism=camp_site objects
-- are obviously bugs, so both types need to be marked.
--
--

BEGIN;

-- First remove old markers
UPDATE osm_poi_campsites SET tags = delete(tags, 'contains_sites') WHERE tags ? 'contains_sites';

-- Now mark campsites that contain others
UPDATE
  osm_poi_campsites cs
SET
  tags = tags || hstore ('contains_sites', si.urls_inner)
FROM (
  SELECT
    o.osm_id AS id_outer,
    o.osm_type AS type_outer,
    string_agg('https://osm.org/' || CASE WHEN i.osm_type = 'W' THEN 'way/' WHEN i.osm_type = 'N' THEN 'node/' ELSE 'relation/' END || i.osm_id::text, ' ') AS urls_inner
  FROM
    osm_poi_campsites o,
    osm_poi_campsites i
  WHERE
    st_contains (o.geom, i.geom)
    AND o.osm_id != i.osm_id
    AND (i.tags -> 'tourism' != 'caravan_site')
  GROUP BY
    o.osm_id,
    o.osm_type) si
WHERE
  si.id_outer = cs.osm_id
  AND si.type_outer = cs.osm_type;

-- First mark all objects as visible
UPDATE osm_poi_campsites SET visible = TRUE;

--
-- Now mark campsites and caravan sites that are inside others as invisible
--
--
UPDATE
  osm_poi_campsites cs
SET
  visible = FALSE
FROM (
  SELECT
    i.osm_id AS id_inner,
    i.osm_type AS type_inner
  FROM
    osm_poi_campsites o,
    osm_poi_campsites i
  WHERE
    st_contains (o.geom, i.geom)
    AND o.osm_id != i.osm_id
  GROUP BY
    i.osm_id,
    i.osm_type) sc
WHERE
  sc.id_inner = cs.osm_id
  AND sc.type_inner = cs.osm_type;

COMMIT;
