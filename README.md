# A POI database made from Openstreetmap data

This uses a setup based on [PostGIS](http://postgis.net) and [imposm](https://github.com/omniscale/imposm3). The database is updated hourly.

Special tables or views based on spatial operations can be created by sql scripts which are
executed right after the hourly updates. Currently only a materialized view containing
campsites is updated at this place.
