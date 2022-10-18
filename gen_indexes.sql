-- generate indexes for imported data

-- Indexes 4 hstore

CREATE INDEX osm_poi_point_tags_index ON osm_poi_point USING GIN (tags);
CREATE INDEX osm_poi_poly_tags_index ON osm_poi_poly USING GIN (tags);

-- Indexes 4 osm_id (this needs an upstream fix)
CREATE INDEX osm_poi_point_osm_id_idx ON osm_poi_point USING btree(osm_id);
CREATE INDEX osm_poi_poly_osm_id_idx ON osm_poi_poly USING btree(osm_id);
CREATE INDEX osm_poi_line_osm_id_idx ON osm_poi_line USING tree(osm_id);

-- Indexes 4 campsites
CREATE INDEX osm_poi_point_campsite_index ON osm_poi_point USING GIST (geom) WHERE (tags->'tourism') = 'camp_site';
CREATE INDEX osm_poi_poly_campsite_index ON osm_poi_poly USING GIST (geom) WHERE (tags->'tourism') = 'camp_site';

CREATE INDEX osm_poi_rels_campsite_index ON osm_poi_poly USING GIST (geom) WHERE (tags->'tourism') = 'camp_site' AND osm_type = 'R';
CREATE INDEX osm_poi_ways_campsite_index ON osm_poi_poly USING GIST (geom) WHERE (tags->'tourism') = 'camp_site' AND osm_type = 'W';

-- Indexes 4 playgrounds
CREATE INDEX osm_poi_point_playground_index ON osm_poi_point USING GIST (geom) WHERE (tags->'leisure') = 'playground';
CREATE INDEX osm_poi_poly_playground_index ON osm_poi_poly USING GIST (geom) WHERE (tags->'leisure') = 'playground';

CREATE INDEX osm_poi_rels_playground_index ON osm_poi_poly USING GIST (geom) WHERE (tags->'leisure') = 'playground' AND osm_type = 'R';
CREATE INDEX osm_poi_ways_playground_index ON osm_poi_poly USING GIST (geom) WHERE (tags->'leisure') = 'playground' AND osm_type = 'W';


