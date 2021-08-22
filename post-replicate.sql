-- SQL script to be called after database update
\i gen_poi_campsites.sql
\i update-poi-campsites-from-siterel.sql

REFRESH MATERIALIZED VIEW CONCURRENTLY osm_poi_playgrounds;
