# How to setup POI database
## Tested with PostgreSQL 10 and 11

* Create database with postgis and hstore enabled
  `createdb -O <yourowner> poi`
  `echo "CREATE EXTENSION HSTORE; CREATE EXTENSION postgis;" |psql poi`
* Install imposm binary on your machine and make it reachable via $PATH
* Adjust imposm-data path in config.json to match your setup
* Call import script (this will take a few hours)
  `./doimport.sh </path/to/planet-latest.osm.pbf> </path/to/config.json>`
* Download countr_osm_grid.sql
  `curl -s http://www.nominatim.org/data/country_grid.sql.gz |gzip -d >country_osm_grid.sql`
* Execute SQL scripts on DB
  `psql -f gen_indexes.sql poi`
  `psql -f country_osm_grid.sql poi`
  `psql -f gen_mview_poi_campsites.sql poi`
* Manually run update.sh until it did catch up
  `./update.sh </path/to/config.json>`
* press crtl-c and re-run as a systemd service using adapted imposm-update.service





