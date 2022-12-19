#!/bin/sh
#
# Initial database import script for osmpoidb
#
# (c) 2022 Sven Geggus <sven-osm@geggus-net>
#

set -e

case $# in
1)
  basepath=/opt/osm2pgsql
  ;;
2)
  basepath=$2
  ;;
*)
  echo "usage: $0 /path/to/planetfile ?basepath?">&2
  exit 1
  ;;
esac

DATA_DIR=${basepath}/data
CODE_DIR=${basepath}/osmpoidb
DBNAME='poi'

cd $DATA_DIR
rm -f flatnode.dat

psql -f country_osm_grid.sql $DBNAME
osm2pgsql -x -s -F flatnode.dat -O flex -S $CODE_DIR/osmpoidb.lua -d $DBNAME $1
psql -f $CODE_DIR/gen_indexes.sql $DBNAME
psql -f $CODE_DIR/gen_poi_campsites.sql $DBNAME
psql -f $CODE_DIR/update-poi-campsites-from-siterel.sql $DBNAME
psql -f $CODE_DIR/update-poi-campsites-with-bugs.sql $DBNAME
echo "ALTER TABLE osm_todo_campsites ADD UNIQUE (osm_type,osm_id);" |psql $DBNAME
psql -f $CODE_DIR/gen_poi_playgrounds.sql $DBNAME
echo "ALTER TABLE osm_todo_playgrounds ADD UNIQUE (osm_type,osm_id);" |psql $DBNAME
psql -f $CODE_DIR/point-poly-trigger.sql $DBNAME
psql -f $CODE_DIR/camp_siterel_trigger.sql $DBNAME

