#!/bin/bash
#
# diff-updates using imposm (1h interval)
#
# (c) 2019 Sven Geggus <sven-osm@geggus-net>
#
# including heuristic to run post_replication script only
# in case of regular intervals and not in catch-up cycles
#

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "uasge: doimport.sh <path/to/config.json> ?post-replicate-script?" >&2
  exit 1
fi

# check if commands we need are available
for cmd in jq date find imposm; do
  if ! command -v $cmd >/dev/null; then
    echo "ERROR: command >>$cmd<< not found, please install!"
    exit 1
  fi
done

DIFFDIR="$(jq -r .diffdir $1)"

if [ -z "$DIFFDIR" ]; then
  echo "diffdir not found in file $1" >&2
  exit 1
fi

if ! [ -d $DIFFDIR ]; then
  echo "$DIFFDIR is not a directory" >&2
  exit 1
fi

# go to script directory
cd $(dirname "$BASH_SOURCE")

if [ $# -eq 2 ]; then
  repl_script=$2  
else
  repl_script="post-replicate.sql"
fi

if ! [ -f $2 ]; then
  echo "file >$2< not found" >&2
  exit 1
fi

# DIFFDIR is now hopefully valid at this stage
export IMPOSM3_SINGLE_DIFF=1

function post_replication() {
  ts=$(date +%Y-%m-%dT%H:%M:%S%:z)
  timestamp=$(date +%s)
  echo "[$ts] 0:00:00 [info] post replication script started"
  psql poi --quiet -f $repl_script
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
