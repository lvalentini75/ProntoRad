-- Migration: Verify and fix availability_slots schema
-- Date: 2026-01-19 31:00:00
-- This ensures all required columns have proper defaults

-- Ensure is_available has a default
ALTER TABLE availability_slots 
  ALTER COLUMN is_available SET DEFAULT true;

-- Ensure is_active has a default  
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' AND column_name = 'is_active'
  ) THEN
    ALTER TABLE availability_slots 
      ALTER COLUMN is_active SET DEFAULT true;
  END IF;
END $$;

-- Ensure created_at has a default
ALTER TABLE availability_slots 
  ALTER COLUMN created_at SET DEFAULT timezone('utc'::text, now());

-- Ensure updated_at has a default
ALTER TABLE availability_slots 
  ALTER COLUMN updated_at SET DEFAULT timezone('utc'::text, now());

-- Ensure booking_id is nullable (it should be NULL for available slots)
ALTER TABLE availability_slots 
  ALTER COLUMN booking_id DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;

-- Ensure staff_user_id is nullable 
DO $$
BEGIN
  ALTER TABLE availability_slots 
    ALTER COLUMN staff_user_id DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- Make sure facility_id is nullable
DO $$
BEGIN
  ALTER TABLE availability_slots 
    ALTER COLUMN facility_id DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- Add comment
COMMENT ON TABLE availability_slots IS 'Stores availability slots for organizations and facilities. Either organization_id or facility_id must be set.';
