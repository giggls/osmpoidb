# A POI database made from Openstreetmap data

This uses a setup based on [PostGIS](http://postgis.net) and [osm2pgsql](https://osm2pgsql.org).
The database is updated in a 10 minute interval.

Special tables based on spatial operations can be created by sql scripts which are
executed right after the hourly updates.

Currently a derived table containing campsites for
https://opencampingmap.org and one containing
playgrounds for https://babykarte.openstreetmap.de/
are updated at this place.

A special feature of these tables is something I call POI in POI which makes
POI of other types located inside POI-Polygons a property of the surounding
object.  E.g. a restaurant located inside a polygon shaped POI tagged
tourism=camp_site will add a feature of type restaurant to the outer POI.

Technically this is done using a PotGIS spatial join using a function called
ST_Intersects.

https://brewmap.openstreetmap.de is also using this database.

