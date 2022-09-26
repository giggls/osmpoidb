-- create MATERIALIZED VIEW osm_poi_playgrounds
-- with list of equipment and sport facilities
--
CREATE MATERIALIZED VIEW osm_poi_playgrounds_tmp AS
SELECT
  poly.osm_id AS osm_id,
  poly.osm_type AS osm_type,
  poly.tags AS tags,
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
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_all AS pt ON poly.geom && pt.geom
WHERE (poly.tags -> 'leisure' = 'playground')
GROUP BY
  poly.osm_id,
  poly.osm_type,
  poly.geom,
  poly.tags
UNION ALL
SELECT
  osm_id,
  osm_type,
  tags,
  geom,
  '{}',
  '{}'
FROM
  osm_poi_point
WHERE (tags -> 'leisure' = 'playground');

-- geometry index
CREATE INDEX osm_poi_playgrounds_geom_tmp ON osm_poi_playgrounds_tmp USING GIST (geom);

-- index on osm_id (UNIQUE)
-- This seems to be needed for CONCURRENTLY REFRESH of MATERIALIZED VIEW
CREATE UNIQUE INDEX osm_poi_playgrounds_osm_id_tmp ON osm_poi_playgrounds_tmp (osm_id,osm_type);

-- this is hopefully atomic enough for a production setup
DROP MATERIALIZED VIEW osm_poi_playgrounds;

ALTER MATERIALIZED VIEW osm_poi_playgrounds_tmp RENAME TO osm_poi_playgrounds;

ALTER INDEX osm_poi_playgrounds_geom_tmp RENAME TO osm_poi_playgrounds_geom;

ALTER INDEX osm_poi_playgrounds_osm_id_tmp RENAME TO osm_poi_playgrounds_osm_id;

GRANT SELECT ON osm_poi_playgrounds TO public;

