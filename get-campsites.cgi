#!/usr/bin/python3
#
# CGI/WSGI wrapper for JSON SQL query with BBOX or site id
#
#
# (c) 2019-2025 Sven Geggus <sven-osm@geggus-net>
#
# Script which can run inside Apache or standalone
#
# Test using the following commands:
# REQUEST_METHOD=GET QUERY_STRING="bbox=-1.38,44.47,-0.95,44.81" ./get-campsites.cgi |tail +5 |jq .
# REQUEST_METHOD=GET QUERY_STRING="osm_id=115074273&osm_type=way" ./get-campsites.cgi |tail +5 |jq .
# REQUEST_METHOD=GET QUERY_STRING="country=li" ./get-campsites.cgi |tail +5 |jq .
#
# or run as server call as follows:
#
# ./get-campsites.cgi --server
# 
# In this case data can then be fetched like this
# GET:
# curl "http://localhost:8000/test?osm_id=115074273&osm_type=way" |jq .
# POST:
# curl -X POST -d "osm_id=115074273" -d "osm_type=way" http://localhost:8000/ |jq .

import psycopg2
import json
import urllib.parse

dbconnstr="dbname=poi"

sql_query="""
SELECT Jsonb_build_object('type', 'FeatureCollection', 'features',
              coalesce(json_agg(features.feature), '[]'::json))
FROM   (SELECT CASE WHEN (osm_type != 'N')
                              THEN Json_build_object('type', 'Feature',
                              'id', 'https://www.openstreetmap.org/' || CASE WHEN osm_type = 'W' THEN 'way/' ELSE 'relation/' END || osm_id,
                              'bbox', array[round(ST_XMin(geom)::numeric,7),round(ST_YMin(geom)::numeric,7),
                                            round(ST_XMax(geom)::numeric,7),round(ST_YMax(geom)::numeric,7)],
                              'geometry',St_asgeojson(ST_PointOnSurface(geom)) :: json, 'properties',
                              CASE WHEN tags ? 'sport' THEN tags - 'sport' || Json_build_object('sport',array_to_json(string_to_array(tags ->> 'sport',';')))::jsonb ELSE tags::jsonb END
                              || Json_build_object('category', category) ::jsonb                              
                              || CASE when telephone = True THEN Json_build_object('telephone','yes') ELSE '{}' END ::jsonb
                              || CASE when post_box = True THEN Json_build_object('post_box','yes') ELSE '{}' END ::jsonb
                              || CASE when drinking_water = True THEN Json_build_object('drinking_water','yes') ELSE '{}' END ::jsonb
                              || CASE when power_supply = True THEN Json_build_object('power_supply','yes') ELSE '{}' END ::jsonb
                              || CASE when shop = True THEN Json_build_object('shop','yes') ELSE '{}' END ::jsonb
                              || CASE when laundry = True THEN Json_build_object('laundry','yes') ELSE '{}' END ::jsonb
                              || CASE when playground = True THEN Json_build_object('playground','yes') ELSE '{}' END ::jsonb
                              || CASE when firepit = True THEN Json_build_object('openfire','yes') ELSE '{}' END ::jsonb
                              || CASE when bbq = True THEN Json_build_object('bbq','yes') ELSE '{}' END ::jsonb
                              || CASE when toilets = True THEN Json_build_object('toilets','yes') ELSE '{}' END ::jsonb
                              || CASE when swimming_pool = True THEN Json_build_object('swimming_pool','yes') ELSE '{}' END ::jsonb
                              || CASE when miniature_golf = True THEN Json_build_object('miniature_golf','yes') ELSE '{}' END ::jsonb
                              || CASE when golf_course = True THEN Json_build_object('golf_course','yes') ELSE '{}' END ::jsonb
                              || CASE when bowling_alley = True THEN Json_build_object('bowling_alley','yes') ELSE '{}' END ::jsonb
                              || CASE when sauna = True THEN Json_build_object('sauna','yes') ELSE '{}' END ::jsonb
                              || CASE when fast_food = True THEN Json_build_object('fast_food','yes') ELSE '{}' END ::jsonb
                              || CASE when restaurant = True THEN Json_build_object('restaurant','yes') ELSE '{}' END ::jsonb
                              || CASE when pub = True THEN Json_build_object('pub','yes') ELSE '{}' END ::jsonb
                              || CASE when bar = True THEN Json_build_object('bar','yes') ELSE '{}' END ::jsonb
                              || CASE when static_caravan = True THEN Json_build_object('static_caravans','yes') ELSE '{}' END ::jsonb
                              || CASE when cabin = True THEN Json_build_object('cabins','yes') ELSE '{}' END ::jsonb
                              || CASE when kitchen = True THEN Json_build_object('kitchen','yes') ELSE '{}' END ::jsonb
                              || CASE when sink = True THEN Json_build_object('sink','yes') ELSE '{}' END ::jsonb
                              || CASE when fridge = True THEN Json_build_object('fridge','yes') ELSE '{}' END ::jsonb
                              || CASE when picnic_table = True THEN Json_build_object('picnic_table','yes') ELSE '{}' END ::jsonb
                              || CASE when shower != 'untagged' THEN Json_build_object('shower',shower) ELSE '{}' END ::jsonb
                              || CASE when sport != '{}' THEN Json_build_object('sport',sport) ELSE '{}' END ::jsonb
                              || CASE WHEN sanitary_dump_station = '{grey_water}' then Json_build_object('sanitary_dump_station','grey_water')
                                      WHEN sanitary_dump_station = '{chemical_toilet}' then Json_build_object('sanitary_dump_station','chemical_toilet')
                                      WHEN sanitary_dump_station = '{yes}' then Json_build_object('sanitary_dump_station','yes')
                                      WHEN 'grey_water'=ANY(sanitary_dump_station) and 'chemical_toilet'=ANY(sanitary_dump_station) then Json_build_object('sanitary_dump_station','grey_water_and_chemical_toilet')
                                      ELSE '{}' END ::jsonb
                              )
                              ELSE Json_build_object('type', 'Feature',
                              'id', 'https://www.openstreetmap.org/node/' || osm_id,
                              'geometry',St_asgeojson(ST_PointOnSurface(geom)) :: json, 'properties',
                              CASE WHEN tags ? 'sport' THEN tags - 'sport' || Json_build_object('sport',array_to_json(string_to_array(tags ->> 'sport',';')))::jsonb ELSE tags::jsonb END
                              || Json_build_object('category', category) ::jsonb
                              )
                              END
        AS    feature
        FROM  osm_poi_campsites
        %s
) features;
"""

sql_where_bbox=" WHERE geom && St_setsrid('BOX3D(%f %f, %f %f)' ::box3d, 4326)"

sql_where_id=" WHERE osm_id = %s AND osm_type = '%s'"

sql_where_country=" WHERE tags ->> 'addr:country'='%s'"

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


def application(env, start_response):
  request_method = env['REQUEST_METHOD']
  status = '200 OK'
    
  if request_method not in ['POST', 'GET']:
    status = '405 Only GET and POST methods allowed'
    
  # GET request
  if request_method == 'GET':
    query_string = env.get('QUERY_STRING', '')
    params = urllib.parse.parse_qs(query_string)
        
  # POST request
  if request_method == 'POST':
    content_length = int(env.get('CONTENT_LENGTH', 0))
    body = env['wsgi.input'].read(content_length).decode('utf-8')
    params = urllib.parse.parse_qs(body)
    
  start_response(status, [('Content-Type', 'application/json')])
    
  # generate response for one of 3 variants: bbox, country or osm_id+osm_type

  # bbox query
  if 'bbox' in params:
    coords=bbox2flist(params['bbox'][0])
    if coords == []:
      return([empty_geojson])
    # bbox sanity check
    if (validate_bbox(coords) == False):
      return([empty_geojson])
  else:
    # country query
    if 'country' in params:
      if params['country'] == []:
        return([empty_geojson])
      if (len(params['country'][0]) > 3) or (len(params['country'][0]) < 2) or (not params['country'][0].isalpha()):
        return([empty_geojson])
      params['country'][0]= params['country'][0].lower()
    else:
     # osm_id query
     if not 'osm_id' in params or not 'osm_type' in params:
       return([empty_geojson])
     else:
       if params['osm_id'] == [] or params['osm_type'] == []:
         return([empty_geojson])
       if not params['osm_id'][0].isdigit():
         return([empty_geojson])
       if not params['osm_type'][0] in ["node","way","relation"]:
         return([empty_geojson])
        
  # At this stage we have valid query options
  try:
    conn = psycopg2.connect(dbconnstr)
  except:
    return([empty_geojson])
  
  # if bbox is given country is ignored
  if 'bbox' in params:
    where_clause = sql_where_bbox % (coords[0],coords[1],coords[2],coords[3])
  else:
    if 'country' in params:
      # no SQL where clause in case of country=all just output all sites
      if params['country'][0] == 'all':
        where_clause = ''
      else:
        where_clause = sql_where_country % params['country'][0]
    else:
      where_clause = sql_where_id % (params['osm_id'][0],params['osm_type'][0][0].upper())
  
  q = sql_query % where_clause
  cur = conn.cursor()
  cur.execute(q)
  res = cur.fetchall()
  json_str = json.dumps(res[0][0])
  conn.close()

  return([json_str.encode()])

# main method is only called for debugging when running as standalone server or one-shot execution
if __name__ == '__main__':
  import sys
  import argparse
  parser = argparse.ArgumentParser(description='Query campsite data from PostGIS in json format')
  parser.add_argument("-c", "--dbconnstr", help="database connection string e.g. dbname=poitest")
  parser.add_argument("-s", "--server", action='store_true', help="run as standalone server")
  parser.add_argument("-p", "--port", type=int, default=8000, help="port for standalone server")
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
