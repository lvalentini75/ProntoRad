-- DIAGNOSTIC QUERY - Check organizations country field status
-- This is a temporary diagnostic migration to verify data
-- Date: 2026-05-06

-- Display current state of all organizations
DO $$
DECLARE
  rec RECORD;
  null_count INTEGER;
  empty_count INTEGER;
  swiss_count INTEGER;
  italian_count INTEGER;
  total_count INTEGER;
BEGIN
  -- Count by category
  SELECT COUNT(*) INTO total_count FROM organizations;
  SELECT COUNT(*) INTO null_count FROM organizations WHERE country IS NULL;
  SELECT COUNT(*) INTO empty_count FROM organizations WHERE country = '';
  SELECT COUNT(*) INTO swiss_count FROM organizations WHERE country = 'Svizzera';
  SELECT COUNT(*) INTO italian_count FROM organizations WHERE country = 'Italia';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DIAGNOSTIC REPORT - Organizations';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total organizations: %', total_count;
  RAISE NOTICE 'With country = NULL: %', null_count;
  RAISE NOTICE 'With country = empty string: %', empty_count;
  RAISE NOTICE 'With country = Svizzera: %', swiss_count;
  RAISE NOTICE 'With country = Italia: %', italian_count;
  RAISE NOTICE '========================================';
  
  -- Show all organizations with their country field
  RAISE NOTICE 'All Organizations Details:';
  FOR rec IN 
    SELECT name, city, province, region, 
           CASE 
             WHEN country IS NULL THEN 'NULL'
             WHEN country = '' THEN 'EMPTY'
             ELSE country
           END as country_status
    FROM organizations 
    ORDER BY region, name
  LOOP
    RAISE NOTICE '  - % | City: %, Province: %, Region: % | Country: %', 
                 rec.name, rec.city, rec.province, rec.region, rec.country_status;
  END LOOP;
  
  RAISE NOTICE '========================================';
END $$;
