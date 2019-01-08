#!/bin/bash

if [ $# -ne 2 ]; then
  echo "uasge: doimport.sh </path/to/planetfile> <path/to/config.json>" >&2
  exit 1
fi

imposm import -config $2 \
 -read $1 \
 -write -diff -dbschema-import="public"

