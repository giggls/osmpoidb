#!/usr/bin/python3
#
# This works with python2.7 and python3
#
# Small CGI/WSGI wrapper for BBOX -> JSON SQL query
#
# (c) 2019 Sven Geggus <sven-osm@geggus-net>
#
#
# test using the following command:
# REQUEST_METHOD=GET QUERY_STRING="bbox=-1.38,44.47,-0.95,44.81" ./get-campsites.cgi |tail +5 |jq .
#
#
import wsgiref.handlers
import cgi
import psycopg2
import json

dbconnstr="dbname=poi"

sql_query="""
SELECT Jsonb_build_object('type', 'FeatureCollection', 'features',
              Jsonb_agg(features.feature))
FROM   (SELECT Json_build_object('type', 'Feature',
                              'id', 'https://www.openstreetmap.org/' || osm_type || '/' || osm_id,
                              'geometry',St_asgeojson(St_centroid(geom)) :: json, 'properties',
                              tags ::jsonb
                              || Json_build_object('category', category) ::jsonb
                              || CASE when restaurant = True THEN Json_build_object('restaurant','yes') ELSE '{}' END ::jsonb
                              || CASE when pub = True THEN Json_build_object('pub','yes') ELSE '{}' END ::jsonb
                              || CASE when bar = True THEN Json_build_object('bar','yes') ELSE '{}' END ::jsonb
                              || CASE when fast_food = True THEN Json_build_object('fast_food','yes') ELSE '{}' END ::jsonb
                              || CASE when pool = True THEN Json_build_object('pool','yes') ELSE '{}' END ::jsonb
                              || CASE when pool = True THEN Json_build_object('pool','yes') ELSE '{}' END ::jsonb
                              || CASE when shower = True THEN Json_build_object('shower','yes') ELSE '{}' END ::jsonb
                              || CASE when toilets = True THEN Json_build_object('toilets','yes') ELSE '{}' END ::jsonb
                              )
        AS    feature
        FROM  osm_poi_campsites
        WHERE geom && St_setsrid('BOX3D(%f %f, %f %f)' ::box3d, 4326)
) features;
"""

# check if bbox contains valid geographical coordinates
def validate_bbox(bbox):
  if (bbox[0] > bbox[2]):
    return(False)
  if (bbox[1] > bbox[3]):
    return(False)
  if (bbox[0] < -180):
    return(False)
  if (bbox[1] < -90):
    return(False)
  if (bbox[2] > 180):
    return(False)
  if (bbox[3] > 90):
    return(False)
  return(True)

# check if bbox contains exactly four floating point numbers  
def bbox2flist(bbox):
  coords=[]
  cl=bbox.split(',')
  if len(cl) != 4:
    return(coords)
  # validate floating point values
  try:
    for c in cl:
      coords.append(float(c))
  except:
    return([])
  return(coords)

def application(environ, start_response):
  start_response('200 OK', [('Content-Type', 'application/json')])
  if not 'REQUEST_METHOD' in environ:
    return([b'{}\n'])
  if environ['REQUEST_METHOD'] not in ['GET', 'POST']:
    return([b'{}\n'])
  if environ['REQUEST_METHOD'] == 'GET':
    if not 'QUERY_STRING' in environ:
      return([b'{}\n'])
    parms = cgi.parse_qs(environ.get('QUERY_STRING', ''))
    bbox = parms.get('bbox', ['0,0,0'])[0]
  else:
    environ['QUERY_STRING'] = ''
    post = cgi.FieldStorage(
        fp=environ['wsgi.input'],
        environ=environ,
        keep_blank_values=True
    )
    bbox = post.getlist("bbox")[0]
    
  # validate floating point values
  coords=bbox2flist(bbox)
  if coords == []:
    return([b'{}\n'])
  # bbox sanity check
  if (validate_bbox(coords) == False):
    return([b'{}\n'])
  
  try:
    conn = psycopg2.connect(dbconnstr)
  except:
    return([b'{}\n'])
  
  q = sql_query % (coords[0],coords[1],coords[2],coords[3])
  cur = conn.cursor()
  cur.execute(q)
  res = cur.fetchall()
  json_str = json.dumps(res[0][0])
  conn.close()

  return([json_str.encode()])
  

if __name__ == '__main__':
  wsgiref.handlers.CGIHandler().run(application)
