-- Migration: Complete exam packages support
-- Date: 2026-05-05 12:21:38
-- Description: Adds missing bookings modifications for package support

-- ============================================================================
-- SECTION 1: Make exam_type_id nullable in bookings (for package bookings)
-- ============================================================================

DO $$
BEGIN
  -- Check if the column has a NOT NULL constraint
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' 
    AND column_name = 'exam_type_id' 
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE bookings ALTER COLUMN exam_type_id DROP NOT NULL;
    RAISE NOTICE 'Made exam_type_id nullable in bookings table';
  ELSE
    RAISE NOTICE 'exam_type_id is already nullable or does not exist';
  END IF;
END $$;

-- ============================================================================
-- SECTION 2: Add check constraint (at least one of exam_type_id or package_id must be set)
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'bookings_exam_or_package_check' 
    AND table_name = 'bookings'
  ) THEN
    ALTER TABLE bookings ADD CONSTRAINT bookings_exam_or_package_check 
      CHECK (exam_type_id IS NOT NULL OR package_id IS NOT NULL);
    RAISE NOTICE 'Added bookings_exam_or_package_check constraint';
  ELSE
    RAISE NOTICE 'Constraint bookings_exam_or_package_check already exists';
  END IF;
END $$;

-- ============================================================================
-- SECTION 3: Ensure package_id column exists with index
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' AND column_name = 'package_id'
  ) THEN
    ALTER TABLE bookings ADD COLUMN package_id UUID NULL REFERENCES exam_packages(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_bookings_package_id ON bookings(package_id);
    RAISE NOTICE 'Added package_id column to bookings';
  ELSE
    RAISE NOTICE 'package_id column already exists';
  END IF;
END $$;
