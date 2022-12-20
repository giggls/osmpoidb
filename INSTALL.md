# How to setup POI database
## (development Platform is Debian 11, PostgreSQL 13, PostGIS 3.1)

* Install requiered Software Packages
```
apt install rtorrent curl sudo
apt install -t bullseye-backports osm2pgsql
```

* Create a user for replication
```
adduser --system --group osm
```

* Create database with postgis and hstore enabled
  ```
  sudo -u postgres createuser osm
  sudo -u postgres createdb -O osm poi
  sudo -u postgres psql -c 'CREATE EXTENSION postgis;' poi
  sudo -u osm psql -c 'CREATE EXTENSION hstore;' poi

  ```

* Prepare data directory
  ```
  export OSM2BASE=/opt/osm2pgsql
  mkdir -p ${OSM2BASE}/data
  chown -r osm:osm ${OSM2BASE}
  ``

* Download Planetfile and countr_osm_grid.sql into data directory
  ```
  cd ${OSM2BASE}/data
  rtorrent https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf.torrent
  curl -s https://nominatim.org/data/country_grid.sql.gz |gzip -d >${OSM2BASE}/data/country_osm_grid.sql
  ```

* Run initial database import
  ```
  cd ${OSM2BASE}
  git clone https://github.com/giggls/osmpoidb
  sudo -u osm osmpoidb/doimport.sh ${OSM2BASE}/data/planet*.pbf ${OSM2BASE}
  ```  

* Init replication
  ```
  sudo -u osm osm2pgsql-replication init -d poi --server https://planet.openstreetmap.org/replication/minute

  ```  

* Enable update service
  If you did not change OSM2BASE to something else than /opt/osm2pgsql just
  do the following:

  ```
  cp poidb-update.* /etc/systemd/system
  ```
  Otherwise fix paths before copying.

  Finaly enable update timer:

  ```
  systemctl enable poidb-update.timer
  systemctl start poidb-update.timer
  ```
