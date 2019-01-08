-- testquery with json output
-- use the following command to call:
-- psql -t -X -f bbox_testquery_json.sql |jq .

SELECT Jsonb_build_object('type', 'FeatureCollection', 'features',
              Jsonb_agg(features.feature))
FROM   (SELECT Json_build_object('type', 'Feature', 'geometry',
                              St_asgeojson(geom) :: json, 'properties',
                              Json_build_object('osm_object', 'https://www.openstreetmap.org/' || osm_type || '/' || osm_id) ::jsonb ||
                              tags ::jsonb
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
        WHERE geom && St_setsrid('BOX3D(-1.38 44.47, -0.95 44.81)' ::box3d, 4326)
) features;
