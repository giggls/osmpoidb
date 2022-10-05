DROP TRIGGER IF EXISTS delete_point_trigger ON osm_poi_point;
DROP TRIGGER IF EXISTS delete_poly_trigger ON osm_poi_poly;

CREATE OR REPLACE FUNCTION delete_object()
  RETURNS TRIGGER 
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
        -- check if object is campsite and delete if so
        IF (OLD.tags -> 'tourism' IN ('camp_site', 'caravan_site')) THEN
          DELETE FROM osm_poi_campsites where osm_id=OLD.osm_id AND osm_type=OLD.osm_type;
        ELSE
          -- if object intersected with a campsite add campsite object to table osm_todo_campsites
          INSERT INTO osm_todo_campsites(osm_id,osm_type,is_cs)                                   
          SELECT osm_id,osm_type,true
          FROM osm_poi_poly
          WHERE (tags -> 'tourism' IN ('camp_site', 'caravan_site'))
          AND ST_Intersects((SELECT geom from osm_poi_all WHERE osm_id=OLD.osm_id AND osm_type=OLD.osm_type),geom)
          ON CONFLICT (osm_id,osm_type) DO NOTHING;
        END IF;

	RETURN OLD;
END;
$$;

CREATE TRIGGER delete_point_trigger BEFORE DELETE ON osm_poi_point FOR EACH ROW EXECUTE PROCEDURE delete_object();
CREATE TRIGGER delete_poly_trigger BEFORE DELETE ON osm_poi_poly FOR EACH ROW EXECUTE PROCEDURE delete_object();