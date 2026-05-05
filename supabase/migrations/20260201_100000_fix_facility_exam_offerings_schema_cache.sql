-- Migration: Fix facility_exam_offerings schema cache
-- Date: 2026-02-01 10:00:00
-- Purpose: Force Supabase to refresh the schema cache for duration_minutes column

-- Drop and recreate the column to force schema cache refresh
DO $$
BEGIN
  -- Check if column exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'facility_exam_offerings' 
      AND column_name = 'duration_minutes'
  ) THEN
    -- Column exists, drop it
    ALTER TABLE facility_exam_offerings DROP COLUMN duration_minutes;
  END IF;
  
  -- Recreate the column
  ALTER TABLE facility_exam_offerings 
    ADD COLUMN duration_minutes INTEGER NOT NULL DEFAULT 30;
    
END $$;

-- Update existing rows to have default value
UPDATE facility_exam_offerings 
SET duration_minutes = 30 
WHERE duration_minutes IS NULL;

-- Refresh materialized views if any (not applicable here, but good practice)
-- Force Supabase to invalidate cache by updating table comment
COMMENT ON TABLE facility_exam_offerings IS 'Offerte esami per struttura - Updated 2026-02-01';
