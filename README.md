# A POI database made from Openstreetmap data

This uses a setup based on [PostGIS](http://postgis.net) and [osm2pgsql](https://osm2pgsql.org).
The database is updated in a 10 minute interval.

Special tables or views based on spatial operations can be created by sql scripts which are
executed right after the hourly updates.

Currently a derived table containing campsites and a table containing
playgrounds is updated at this place.
