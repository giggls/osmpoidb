# How to setup POI database
## (development Platform is Debian 11, PostgreSQL 13, PostGIS 3.1)

* Create database with postgis and hstore enabled
  ```
  createdb -O <yourowner> poi
  echo "CREATE EXTENSION postgis;" |psql poi
  ```
* Install osm2pgsql 1.7.0 or higher

* Run initial database import

* Download countr_osm_grid.sql
```
  curl -s http://www.nominatim.org/data/country_grid.sql.gz |gzip -d >country_osm_grid.sql
```
* Execute SQL scripts on DB:
```
  psql -f gen_indexes.sql poi
  psql -f country_osm_grid.sql poi
  psql -f gen_poi_campsites.sql poi
  psql -f update-poi-campsites-from-siterel.sql poi
  psql -f update-poi-campsites-with-bugs.sql poi
  psql -f gen_mview_poi_playgrounds.sql poi
 ```



