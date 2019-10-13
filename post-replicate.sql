-- script to be called after database update

REFRESH MATERIALIZED VIEW CONCURRENTLY osm_poi_campsites;
REFRESH MATERIALIZED VIEW CONCURRENTLY osm_poi_playgrounds;

