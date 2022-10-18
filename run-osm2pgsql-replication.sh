#!/bin/sh

DATA_DIR=/opt/osm2pgsql/data
CODE_DIR=/opt/osm2pgsql/osmpoidb
DBNAME='poi'

set -e

cd $CODE_DIR
# in case something went wrong in previous cycle delete old stuff
echo "DELETE FROM osm_todo_campsites; DELETE FROM osm_todo_cs_trigger;" |psql -q $DBNAME
echo "DELETE FROM osm_todo_playgrounds; DELETE FROM osm_todo_pg_trigger;" |psql -q $DBNAME
osm2pgsql-replication update -d $DBNAME --post-processing ./post-update.sh -- -x -O flex -F $DATA_DIR/flatnode.dat -S osmpoidb.lua




