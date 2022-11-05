
DROP TRIGGER IF EXISTS delete_camp_siterel_trigger ON osm_poi_camp_siterel;

CREATE OR REPLACE FUNCTION del_csr_triggerfunc()
  RETURNS TRIGGER 
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
        -- check if refered object is camp_site and add to osm_todo_cs_trigger if so
        INSERT INTO osm_todo_cs_trigger(osm_id,osm_type)
        SELECT member_id,member_type
        FROM osm_poi_camp_siterel_extended
        WHERE member_tags->'tourism' IN ('camp_site', 'caravan_site')
        AND site_id=OLD.site_id;

        RETURN OLD;
END;
$$;

CREATE TRIGGER delete_camp_siterel_trigger BEFORE DELETE ON osm_poi_camp_siterel FOR EACH ROW EXECUTE PROCEDURE del_csr_triggerfunc();
