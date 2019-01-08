-- generate indexes for imported data

-- Indexes 4 hstore

CREATE INDEX osm_poi_point_tags_index ON osm_poi_point USING GIN (tags);
CREATE INDEX osm_poi_poly_tags_index ON osm_poi_poly USING GIN (tags);

-- Indexes 4 campsites
CREATE INDEX osm_poi_point_campsite_index ON osm_poi_point USING GIST (geom) WHERE (tags->'tourism') = 'camp_site';
CREATE INDEX osm_poi_poly_campsite_index ON osm_poi_poly USING GIST (geom) WHERE (tags->'tourism') = 'camp_site';
