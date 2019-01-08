#!/bin/bash
#
# diff-updates using imposm (1h interval)
#
# (c) 2019 Sven Geggus <sven-osm@geggus-net>
#
# including heuristic to run post_replication script only
# in case of regular intervals and not in catch-up cycles
#

if [ $# -ne 1 ]; then
  echo "uasge: doimport.sh <path/to/config.json>" >&2
  exit 1
fi

# this is json parsing for the poor :)
DIFFDIR=$(grep diffdir $1 |cut -d : -f 2 |sed -e 's/,*[[:space:]]*$//' -e 's/^[[:space:]]*//' -e 's/^["'"'"']//' -e 's/["'"'"']$//')

if [ -z "$DIFFDIR" ]; then
  echo "diffdir not found in file $1" >&2
  exit 1
fi

if ! [ -d $DIFFDIR ]; then
    echo "$DIFFDIR is not a directory"
    exit 1
fi

# DIFFDIR is now hopefully valid at this stage

export IMPOSM3_SINGLE_DIFF=1

function post_replication() {
  ts=$(date +%Y-%m-%dT%H:%M:%S%:z)
  timestamp=$(date +%s)
  echo "[$ts] 0:00:00 [info] post replication script started"
  echo "REFRESH MATERIALIZED VIEW osm_poi_campsites;" |psql poi --quiet
  # remove diff import files older than 2 hours
  find $DIFFDIR -type f \! -name "last.state.txt" -mmin +120 -exec rm {} \;
  ts=$(date +%Y-%m-%dT%H:%M:%S%:z)
  now=$(date +%s)
  diff=$(($now-$timestamp))
  elapsed=$(date -u -d @$diff +'%-H:%M:%S')
  echo "[$ts] $elapsed [info] post replication script finished"
}

while true; do
  timestamp=$(date +%s)

  # call single diff imposm replication
  imposm run -config $1

  now=$(date +%s)

  diff=$(($now-$timestamp))

  # run post replication script only 
  # if replication stopped for more than 20 minutes
  if (( diff > 1800 )); then
    post_replication
  fi
done
