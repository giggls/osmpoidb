#!/usr/bin/python3
#
# Query import date from osm2pgsql replicate table
#
# (c) 2023 Sven Geggus <sven-osm@geggus-net>
#
import wsgiref.handlers
import psycopg2
from datetime import timezone
from dateutil import parser

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
  timestamp = str(parser.parse(res[0][0]).replace(tzinfo=None)).encode()
  conn.close()
  return([b'{ "importdate": "%s" }\n' % timestamp])
  

if __name__ == '__main__':
  wsgiref.handlers.CGIHandler().run(application)
