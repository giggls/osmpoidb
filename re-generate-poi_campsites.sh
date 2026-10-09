#!/bin/sh
#
# Re-generate table osm_poi_campsites
# handy in case of added new features
#
# (c) 2026 Sven Geggus <sven-osm@geggus-net>
#

set -e

DBNAME='poi'

psql -f gen_poi_campsites.sql $DBNAME
exit 0

psql -f update-poi-campsites-from-siterel.sql $DBNAME
psql -f update-poi-campsites-with-bugs.sql $DBNAME
echo "ALTER TABLE osm_todo_campsites ADD UNIQUE (osm_type,osm_id);" |psql $DBNAME
psql -f point-poly-trigger.sql $DBNAME
psql -f camp_siterel_trigger.sql $DBNAME

