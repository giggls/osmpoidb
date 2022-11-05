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
  mkdir -p /opt/osm2pgsql/data
  chown -r osm:osm /opt/osm2pgsql
  ``

* Download Planetfile and countr_osm_grid.sql into data directory
  ```
  cd /opt/osm2pgsql/data
  rtorrent https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf.torrent
  curl -s https://nominatim.org/data/country_grid.sql.gz |gzip -d >/opt/osm2pgsql/data/country_osm_grid.sql
  ```
* Import country_osm_grid

  ```
  sudo -u osm psql -f /opt/osm2pgsql/data/country_osm_grid.sql poi

  ```

* Run initial database import
  ```
  cd /opt/osm2pgsql
  git clone github.com/giggls/osmpoidb
  sudo -u osm osmpoidb/doimport.sh /opt/osm2pgsql/data/planet*.pbf
  ```  

* Init replication
  ```
  sudo -u osm osm2pgsql-replication init -d poi --server https://planet.openstreetmap.org/replication/minute

  ```  

* Enable update service
  ```
  cp poidb-update.* /etc/systemd/system
  systemctl enable poidb-update.timer
  systemctl start poidb-update.timer
  ```

