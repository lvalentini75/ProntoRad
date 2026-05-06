-- Migration: Fix country field for Swiss hospitals
-- Date: 2026-05-06
-- Description: Update country field for all Swiss hospitals to ensure proper filtering

-- Update all hospitals in Swiss cantons to have country = 'Svizzera'
UPDATE organizations
SET country = 'Svizzera', updated_at = NOW()
WHERE region = 'Ticino' AND (country IS NULL OR country != 'Svizzera');

-- Verify the update
DO $$
DECLARE
  swiss_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO swiss_count
  FROM organizations
  WHERE country = 'Svizzera';
  
  RAISE NOTICE '✅ Swiss hospitals with country field set: %', swiss_count;
END $$;
