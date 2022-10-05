#!/bin/sh

CODE_DIR=/opt/osm2pgsql/osmpoidb
DBNAME='poi'

set -e

cd $CODE_DIR
date +'%Y-%m-%d %H:%M:%S calling post-update.sql'
psql -f post-update.sql $DBNAME
date +'%Y-%m-%d %H:%M:%S calling update-poi-campsites-from-siterel.sql'
psql -f update-poi-campsites-from-siterel.sql $DBNAME
date +'%Y-%m-%d %H:%M:%S calling update-poi-campsites-with-bugs.sql'
psql -f update-poi-campsites-with-bugs.sql $DBNAME


