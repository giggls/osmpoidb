CREATE OR REPLACE FUNCTION
imposm_type2str(imposm_type smallint) returns text as $$ 
BEGIN
  IF imposm_type = 0 THEN
    RETURN 'node';
  END IF;
  IF imposm_type = 1 THEN
    RETURN 'way';
  END IF;
  IF imposm_type = 2 THEN
    RETURN 'relation';
  END IF;
  RETURN '';
END
$$ language plpgsql;
