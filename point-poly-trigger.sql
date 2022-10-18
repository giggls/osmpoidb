
-- the table we write campsite ids to which need to get refreshed
CREATE TABLE IF NOT EXISTS osm_todo_cs_trigger (osm_type char(1), osm_id bigint);

-- the table we write playground ids to which need to get refreshed
CREATE TABLE IF NOT EXISTS osm_todo_pg_trigger (osm_type char(1), osm_id bigint);

DROP TRIGGER IF EXISTS delete_point_trigger ON osm_poi_point;
DROP TRIGGER IF EXISTS delete_poly_trigger ON osm_poi_poly;

CREATE OR REPLACE FUNCTION delete_object()
  RETURNS TRIGGER 
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
        -- check if object is playground and delete if so
        IF (OLD.tags -> 'leisure' = 'playground') THEN
          DELETE FROM osm_poi_playgrounds where osm_id=OLD.osm_id AND osm_type=OLD.osm_type;
        ELSE
          -- if object intersected with a polygon shaped playground add playground object to table osm_todo_pg_trigger
          INSERT INTO osm_todo_pg_trigger(osm_id,osm_type)
          SELECT osm_id,osm_type
          FROM osm_poi_poly
          WHERE (tags -> 'leisure' = 'playground')
          AND ST_Intersects((SELECT geom from osm_poi_all WHERE osm_id=OLD.osm_id AND osm_type=OLD.osm_type limit 1),geom);
        END IF;

        -- check if object is campsite and delete if so
        IF (OLD.tags -> 'tourism' IN ('camp_site', 'caravan_site')) THEN
          DELETE FROM osm_poi_campsites where osm_id=OLD.osm_id AND osm_type=OLD.osm_type;
        ELSE
          -- if object intersected with a polygon shaped campsite add campsite object to table osm_todo_cs_trigger
          INSERT INTO osm_todo_cs_trigger(osm_id,osm_type)                                   
          SELECT osm_id,osm_type
          FROM osm_poi_poly
          WHERE (tags -> 'tourism' IN ('camp_site', 'caravan_site'))
          AND ST_Intersects((SELECT geom from osm_poi_all WHERE osm_id=OLD.osm_id AND osm_type=OLD.osm_type limit 1),geom);
        END IF;

	RETURN OLD;
END;
$$;

CREATE TRIGGER delete_point_trigger BEFORE DELETE ON osm_poi_point FOR EACH ROW EXECUTE PROCEDURE delete_object();
CREATE TRIGGER delete_poly_trigger BEFORE DELETE ON osm_poi_poly FOR EACH ROW EXECUTE PROCEDURE delete_object();
