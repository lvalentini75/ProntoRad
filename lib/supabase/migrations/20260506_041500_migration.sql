-- Migration: Fix country field for all Swiss and Italian hospitals
-- Date: 2026-05-06
-- Description: Ensure all hospitals have the correct country field set

-- First, set default country to 'Italia' for any NULL values
UPDATE organizations
SET country = 'Italia', updated_at = NOW()
WHERE country IS NULL OR country = '';

-- Then update Swiss hospitals based on region
UPDATE organizations
SET country = 'Svizzera', updated_at = NOW()
WHERE region IN (
  'Argovia', 'Appenzello Esterno', 'Appenzello Interno', 'Basilea Campagna', 
  'Basilea Città', 'Berna', 'Friburgo', 'Ginevra', 'Glarona', 'Grigioni', 
  'Giura', 'Lucerna', 'Neuchâtel', 'Nidvaldo', 'Obvaldo', 'San Gallo', 
  'Sciaffusa', 'Soletta', 'Svitto', 'Turgovia', 'Ticino', 'Uri', 'Vallese', 
  'Vaud', 'Zugo', 'Zurigo'
);

-- Verify and report
DO $$
DECLARE
  swiss_count INTEGER;
  italian_count INTEGER;
  total_count INTEGER;
  rec RECORD;
BEGIN
  SELECT COUNT(*) INTO swiss_count FROM organizations WHERE country = 'Svizzera';
  SELECT COUNT(*) INTO italian_count FROM organizations WHERE country = 'Italia';
  SELECT COUNT(*) INTO total_count FROM organizations;
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Migration completed successfully';
  RAISE NOTICE 'Total organizations: %', total_count;
  RAISE NOTICE 'Swiss hospitals: %', swiss_count;
  RAISE NOTICE 'Italian hospitals: %', italian_count;
  RAISE NOTICE '========================================';
  
  -- Show Swiss hospitals details
  IF swiss_count > 0 THEN
    RAISE NOTICE 'Swiss Hospitals:';
    FOR rec IN 
      SELECT name, city, region FROM organizations WHERE country = 'Svizzera' ORDER BY name
    LOOP
      RAISE NOTICE '  - % (%, %)', rec.name, rec.city, rec.region;
    END LOOP;
  END IF;
END $$;
