#!/bin/sh

DATA_DIR=/opt/osm2pgsql/data
CODE_DIR=/opt/osm2pgsql/osmpoidb
DBNAME='poi'

set -e

cd $CODE_DIR
osm2pgsql-replication update -d $DBNAME --post-processing ./post-update.sh -- -O flex -F $DATA_DIR/flatnode.dat -S osmpoidb.lua




