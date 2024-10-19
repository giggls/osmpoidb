#!/usr/bin/python3
#
# This works with python2.7 and python3
#
# Small CGI/WSGI wrapper for JSON SQL query with BBOX or site id
#
# (c) 2019 Sven Geggus <sven-osm@geggus-net>
#
#
# test using the following commands:
# REQUEST_METHOD=GET QUERY_STRING="bbox=-1.38,44.47,-0.95,44.81" ./get-campsites.cgi |tail +5 |jq .
# REQUEST_METHOD=GET QUERY_STRING="osm_id=115074273&osm_type=way" ./get-campsites.cgi |tail +5 |jq .
# REQUEST_METHOD=GET QUERY_STRING="country=li" ./get-campsites.cgi |tail +5 |jq .
#
import wsgiref.handlers
import psycopg2
import json
import urllib
import multipart

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
                              || CASE when sanitary_dump_station = True THEN Json_build_object('sanitary_dump_station','yes') ELSE '{}' END ::jsonb
                              || CASE when firepit = True THEN Json_build_object('openfire','yes') ELSE '{}' END ::jsonb
                              || CASE when bbq = True THEN Json_build_object('bbq','yes') ELSE '{}' END ::jsonb
                              || CASE when toilets = True THEN Json_build_object('toilets','yes') ELSE '{}' END ::jsonb
                              || CASE when shower = True THEN Json_build_object('shower','yes') ELSE '{}' END ::jsonb
                              || CASE when swimming_pool = True THEN Json_build_object('swimming_pool','yes') ELSE '{}' END ::jsonb
                              || CASE when miniature_golf = True THEN Json_build_object('miniature_golf','yes') ELSE '{}' END ::jsonb
                              || CASE when golf_course = True THEN Json_build_object('golf_course','yes') ELSE '{}' END ::jsonb
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
                              || CASE when sport != '{}' THEN Json_build_object('sport',sport) ELSE '{}' END ::jsonb
                              )
                              ELSE Json_build_object('type', 'Feature',
                              'id', 'https://www.openstreetmap.org/node/' || osm_id,
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
                              || CASE when sanitary_dump_station = True THEN Json_build_object('sanitary_dump_station','yes') ELSE '{}' END ::jsonb
                              || CASE when firepit = True THEN Json_build_object('openfire','yes') ELSE '{}' END ::jsonb
                              || CASE when bbq = True THEN Json_build_object('bbq','yes') ELSE '{}' END ::jsonb
                              || CASE when toilets = True THEN Json_build_object('toilets','yes') ELSE '{}' END ::jsonb
                              || CASE when shower = True THEN Json_build_object('shower','yes') ELSE '{}' END ::jsonb
                              || CASE when swimming_pool = True THEN Json_build_object('swimming_pool','yes') ELSE '{}' END ::jsonb
                              || CASE when miniature_golf = True THEN Json_build_object('miniature_golf','yes') ELSE '{}' END ::jsonb
                              || CASE when golf_course = True THEN Json_build_object('golf_course','yes') ELSE '{}' END ::jsonb
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
                              || CASE when sport != '{}' THEN Json_build_object('sport',sport) ELSE '{}' END ::jsonb
                              )
                              END
        AS    feature
        FROM  osm_poi_campsites
        WHERE %s
) features;
"""

sql_where_bbox="geom && St_setsrid('BOX3D(%f %f, %f %f)' ::box3d, 4326)"

sql_where_id="osm_id = %s AND osm_type = '%s'"

sql_where_country="tags ->> 'addr:country'='%s'"

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

  bbox = []
  osm_id = []
  osm_type = []
  country = []

  # callbacks sets required variables
  # for POST request + multipart module
  def on_field(field):
    if (field.field_name == b'bbox'):
      bbox.append(field.value.decode())
    if (field.field_name == b'osm_id'):
      osm_id.append(field.value.decode())
    if (field.field_name == b'osm_type'):
      osm_type.append(field.value.decode())
    if (field.field_name == b'country'):
      country.append(field.value.decode())

  def on_file(file):
    pass

  start_response('200 OK', [('Content-Type', 'application/json')])
  if not 'REQUEST_METHOD' in environ:
    return([empty_geojson])
  if environ['REQUEST_METHOD'] not in ['GET', 'POST']:
    return([b'{}\n'])
  if environ['REQUEST_METHOD'] == 'GET':
    if not 'QUERY_STRING' in environ:
      return([empty_geojson])
    parms = urllib.parse.parse_qs(environ.get('QUERY_STRING', ''))
    bbox = parms.get('bbox')
    osm_id = parms.get('osm_id')
    osm_type = parms.get('osm_type')
    country = parms.get('country')
  else:
    environ['QUERY_STRING'] = ''
    multipart.parse_form({'Content-Type': environ['CONTENT_TYPE']}, environ['wsgi.input'], on_field, on_file)
    
  if ((bbox is not None) and (bbox != [])):
    # validate floating point values in bbox
    coords=bbox2flist(bbox[0])
    if coords == []:
      return([empty_geojson])
    # bbox sanity check
    if (validate_bbox(coords) == False):
      return([empty_geojson])
  else:
    # country query
    if ((country is not None) and (country != [])):
      if (len(country[0]) > 3) or (len(country[0]) < 2) or (not country[0].isalpha()):
        return([empty_geojson])
      country[0] = country[0].lower()
    else:
      # osm_id query
      if ((osm_id is not None) and (osm_id != [])
        and (osm_type is not None) and (osm_type != [])):
        # validate osm_id (must be numeric)
        if not osm_id[0].isdigit():
          return([empty_geojson])
        if not osm_type[0] in ["node","way","relation"]:
          return([empty_geojson])
      else:
        return([empty_geojson])

  try:
    conn = psycopg2.connect(dbconnstr)
  except:
    return([empty_geojson])
  
  # if bbox is given country is ignored
  if ((bbox is not None) and (bbox != [])):
    q = sql_where_bbox % (coords[0],coords[1],coords[2],coords[3])
  else:
    if ((country is not None) and (country != [])):
      q = sql_where_country % country[0]
    else:
      q = sql_where_id % (osm_id[0],osm_type[0][0].upper())
  
  q = sql_query % q
  cur = conn.cursor()
  cur.execute(q)
  res = cur.fetchall()
  json_str = json.dumps(res[0][0])
  conn.close()

  return([json_str.encode()])
  

if __name__ == '__main__':
  wsgiref.handlers.CGIHandler().run(application)
