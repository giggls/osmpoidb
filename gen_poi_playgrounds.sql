-- create TABLE osm_poi_playgrounds
-- with list of equipment and sport facilities
--
CREATE TABLE osm_poi_playgrounds AS
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
        pt.tags ->> 'playground'
      END), NULL) AS equipment,
  -- This will produce a list of available sport facilities on the premises
  array_remove(array_agg(DISTINCT CASE WHEN (_st_intersects (poly.geom, pt.geom)
        AND (pt.tags ? 'sport')
        AND (pt.osm_id != poly.osm_id)) THEN
        pt.tags ->> 'sport'
      END), NULL) AS sport
FROM
  osm_poi_poly AS poly
  LEFT JOIN osm_poi_all AS pt ON poly.geom && pt.geom
WHERE (poly.tags ->> 'leisure' = 'playground')
GROUP BY
  poly.osm_id,
  poly.osm_type,
  poly.geom,
  poly.tags,
  poly.timestamp
UNION ALL
SELECT
  osm_id,
  osm_type,
  tags,
  timestamp,
  geom,
  '{}',
  '{}'
FROM
  osm_poi_point
WHERE (tags ->> 'leisure' = 'playground');

-- geometry index
CREATE INDEX osm_poi_playgrounds_geom ON osm_poi_playgrounds USING GIST (geom);

-- index on osm_id (UNIQUE) maybe not needed
--CREATE UNIQUE INDEX osm_poi_playgrounds_osm_id ON osm_poi_playgrounds (id);

-- index on osm_type
CREATE INDEX osm_poi_playgrounds_osm_type ON osm_poi_playgrounds (osm_type);

GRANT SELECT ON osm_poi_playgrounds TO public;

