#!/bin/sh
#
# Initial database import script for osmpoidb
#
# (c) 2022 Sven Geggus <sven-osm@geggus-net>
#
if [ $# -ne 1 ]; then
   echo "usage: $0 /path/to/planetfile" >&2
   exit 1
fi

set -e

DATA_DIR=/opt/osm2pgsql/data
CODE_DIR=/opt/osm2pgsql/osmpoidb
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

