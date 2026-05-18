#!/usr/bin/python3
#
# Query import date from osm2pgsql replicate table
#
# (c) 2023-2025 Sven Geggus <sven-osm@geggus-net>
#
import psycopg2
from datetime import timezone
import dateutil.parser

dbconnstr="dbname=poi"

sql_query="select value from osm2pgsql_properties where property = 'replication_timestamp';"

def application(environ, start_response):
  start_response('200 OK', [('Content-Type', 'application/json')])
  
  try:
    conn = psycopg2.connect(dbconnstr)
  except:
    return([b'{}\n'])
  
  cur = conn.cursor()
  cur.execute(sql_query)
  res = cur.fetchall()
  if res != []:
    timestamp = str(dateutil.parser.parse(res[0][0]).replace(tzinfo=None)).encode()
  else:
    timestamp = b"0000-00-00 00:00:00"
  conn.close()
  return([b'{ "importdate": "%s" }\n' % timestamp])
  

if __name__ == '__main__':
  import sys
  import argparse
  parser = argparse.ArgumentParser(description='Query PostGIS import/update date')
  parser.add_argument("-c", "--dbconnstr", help="database connection string e.g. dbname=poitest")
  parser.add_argument("-s", "--server", action='store_true', help="run as standalone server")
  parser.add_argument("-p", "--port", type=int, default=8001, help="port for standalone server")
  args = parser.parse_args()
  
  # overwrite DB connection string if requested
  if args.dbconnstr is not None:
    dbconnstr=args.dbconnstr

  if args.server:
    import wsgiref.simple_server
    server = wsgiref.simple_server.make_server('', args.port, application)
    print("Server running on http://localhost:%d" % args.port)
    server.serve_forever()
  else:
    import wsgiref.handlers

  wsgiref.handlers.CGIHandler().run(application)
