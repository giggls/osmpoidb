#!/usr/bin/python3
#
# This works with python2.7 and python3
#
# Small CGI/WSGI wrapper for BBOX -> JSON SQL query
#
# (c) 2019 Sven Geggus <sven-osm@geggus-net>
#
#
# test using the following commands:
# REQUEST_METHOD=GET QUERY_STRING="bbox=11.11,49.42,11.13,49.43" ./get-campsite-features.cgi |tail +5 |jq .
#
import wsgiref.handlers
import cgi
import psycopg2
import json
from urllib.parse import parse_qs

dbconnstr="dbname=poi"

sql_query="""
SELECT Jsonb_build_object('type', 'FeatureCollection', 'features',
              coalesce(json_agg(features.feature), '[]'::json))
FROM   (
  SELECT
    Json_build_object('type', 'Feature',
    'id', osm_id,
    'geometry',St_asgeojson(geom) :: json, 'properties',
    tags ::jsonb)
  AS feature
  FROM  osm_poi_point
  WHERE geom && ST_SetSRID('BOX3D(%f %f, %f %f)'::box3d,4326) and ((tags->'tourism' = 'camp_pitch') or (tags->'amenity' = 'power_supply'))
  UNION ALL
  SELECT
    Json_build_object('type', 'Feature',
    'id', osm_id,
    'geometry',St_asgeojson(geom) :: json, 'properties',
    tags ::jsonb)
  AS feature
  FROM  osm_poi_poly
  WHERE geom && ST_SetSRID('BOX3D(%f %f, %f %f)'::box3d,4326) and (tags->'tourism' = 'camp_pitch')
) features;
"""
empty_geojson = b'{"type": "FeatureCollection", "features": []}\n'

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
    return([empty_geojson])
  if environ['REQUEST_METHOD'] not in ['GET', 'POST']:
    return([b'{}\n'])
  if environ['REQUEST_METHOD'] == 'GET':
    if not 'QUERY_STRING' in environ:
      return([empty_geojson])
    parms = parse_qs(environ.get('QUERY_STRING', ''))
    bbox = parms.get('bbox')
  else:
    environ['QUERY_STRING'] = ''
    post = cgi.FieldStorage(
        fp=environ['wsgi.input'],
        environ=environ,
        keep_blank_values=True
    )
    bbox = post.getlist("bbox")
    
  if ((bbox is not None) and (bbox != [])):
    # validate floating point values in bbox
    coords=bbox2flist(bbox[0])
    if coords == []:
      return([empty_geojson])
    # bbox sanity check
    if (validate_bbox(coords) == False):
      return([empty_geojson])

    try:
      conn = psycopg2.connect(dbconnstr)
    except:
      return([empty_geojson])
  
    q = sql_query % (coords[0],coords[1],coords[2],coords[3],coords[0],coords[1],coords[2],coords[3])
  
    cur = conn.cursor()
    cur.execute(q)
    res = cur.fetchall()
    json_str = json.dumps(res[0][0])
    conn.close()

    return([json_str.encode()])
  return([empty_geojson])
  

if __name__ == '__main__':
  wsgiref.handlers.CGIHandler().run(application)
