#!/bin/sh

DBNAME='poi'

set -e

echo -n "$(date +'%Y-%m-%d %H:%M:%S')  calling post-update.sql..."
t1=$(date +%s)
psql -q -f post-update.sql $DBNAME
t2=$(date +%s)
echo " done in $(expr $t2 - $t1)s."

echo -n "$(date +'%Y-%m-%d %H:%M:%S')  calling update-poi-campsites-with-bugs.sql..."
psql -q -f update-poi-campsites-with-bugs.sql $DBNAME
t1=$(date +%s)
echo " done in $(expr $t1 - $t2)s."


