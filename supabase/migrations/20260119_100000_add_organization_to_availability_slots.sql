-- Migration: Add organization_id to availability_slots and fix column names
-- Date: 2026-01-19 10:00:00
-- This migration aligns availability_slots schema with the current application code
-- Reason: Code uses organization_id and exam_type_id, but DB has facility_id and exam_id

-- ============================================================================
-- SECTION 1: Add organization_id to availability_slots table
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE availability_slots ADD COLUMN organization_id UUID NULL;
    ALTER TABLE availability_slots ADD CONSTRAINT availability_slots_organization_id_fkey 
      FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
    CREATE INDEX idx_availability_slots_organization_id ON availability_slots(organization_id);
  END IF;
END $$;

-- ============================================================================
-- SECTION 2: Add exam_type_id as alias/replacement for exam_id
-- ============================================================================

-- Add exam_type_id column if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' AND column_name = 'exam_type_id'
  ) THEN
    -- Add the new column
    ALTER TABLE availability_slots ADD COLUMN exam_type_id UUID NULL;
    
    -- Copy data from exam_id to exam_type_id if exam_id exists
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'availability_slots' AND column_name = 'exam_id'
    ) THEN
      UPDATE availability_slots SET exam_type_id = exam_id WHERE exam_id IS NOT NULL;
    END IF;
    
    -- Add foreign key constraint
    ALTER TABLE availability_slots ADD CONSTRAINT availability_slots_exam_type_id_fkey 
      FOREIGN KEY (exam_type_id) REFERENCES exam_types(id) ON DELETE RESTRICT;
    CREATE INDEX idx_availability_slots_exam_type_id ON availability_slots(exam_type_id);
  END IF;
END $$;

-- ============================================================================
-- SECTION 3: Make facility_id nullable (since we now use organization_id)
-- ============================================================================

DO $$
BEGIN
  -- Drop the NOT NULL constraint if exists
  ALTER TABLE availability_slots ALTER COLUMN facility_id DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN
    -- Already nullable, ignore
    NULL;
END $$;

-- Also make exam_id nullable since we use exam_type_id now
DO $$
BEGIN
  ALTER TABLE availability_slots ALTER COLUMN exam_id DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END $$;

-- ============================================================================
-- SECTION 4: Add specific_date column for date-based slots
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' AND column_name = 'specific_date'
  ) THEN
    ALTER TABLE availability_slots ADD COLUMN specific_date DATE NULL;
    CREATE INDEX idx_availability_slots_specific_date ON availability_slots(specific_date);
  END IF;
END $$;

-- ============================================================================
-- SECTION 5: Add day_of_week column for recurring slots
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' AND column_name = 'day_of_week'
  ) THEN
    ALTER TABLE availability_slots ADD COLUMN day_of_week INTEGER NULL 
      CHECK (day_of_week >= 0 AND day_of_week <= 6);
  END IF;
END $$;

-- ============================================================================
-- SECTION 6: Add max_bookings column
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' AND column_name = 'max_bookings'
  ) THEN
    ALTER TABLE availability_slots ADD COLUMN max_bookings INTEGER DEFAULT 1;
  END IF;
END $$;

-- ============================================================================
-- SECTION 7: Backfill organization_id from facility where possible
-- ============================================================================

UPDATE availability_slots a
SET organization_id = f.organization_id
FROM facilities f
WHERE a.facility_id = f.id
  AND a.organization_id IS NULL
  AND f.organization_id IS NOT NULL;

-- ============================================================================
-- SECTION 8: Backfill specific_date from start_time for existing slots
-- ============================================================================

UPDATE availability_slots
SET specific_date = start_time::date
WHERE specific_date IS NULL 
  AND start_time IS NOT NULL;

-- ============================================================================
-- SECTION 9: Update RLS policies for availability_slots to use organization_id
-- ============================================================================

-- Drop old policies
DROP POLICY IF EXISTS "Public can view available slots" ON availability_slots;
DROP POLICY IF EXISTS "Org admins can view org slots" ON availability_slots;
DROP POLICY IF EXISTS "Org admins can manage org slots" ON availability_slots;
DROP POLICY IF EXISTS "Super admins can manage all slots" ON availability_slots;

-- Public can view available slots
CREATE POLICY "Public can view available slots"
  ON availability_slots FOR SELECT
  USING (is_available = true AND is_active = true);

-- Org admins can view all slots for their organization
CREATE POLICY "Org admins can view org slots"
  ON availability_slots FOR SELECT TO authenticated
  USING (
    is_org_admin() AND (
      -- Match by organization_id directly
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = availability_slots.organization_id
      )
      OR
      -- Fallback: match by facility_id -> organization
      (availability_slots.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = availability_slots.facility_id 
          AND f.organization_id = u.organization_id
      ))
      -- Also match by staff_user_id (creator can always view their slots)
      OR
      (availability_slots.staff_user_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.id = availability_slots.staff_user_id
      ))
    )
  );

-- Org admins can manage (INSERT, UPDATE, DELETE) slots for their organization
CREATE POLICY "Org admins can manage org slots"
  ON availability_slots FOR ALL TO authenticated
  USING (
    is_org_admin() AND (
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = availability_slots.organization_id
      )
      OR
      (availability_slots.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = availability_slots.facility_id 
          AND f.organization_id = u.organization_id
      ))
      OR
      (availability_slots.staff_user_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.id = availability_slots.staff_user_id
      ))
    )
  )
  WITH CHECK (
    is_org_admin() AND (
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = availability_slots.organization_id
      )
      OR
      (availability_slots.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = availability_slots.facility_id 
          AND f.organization_id = u.organization_id
      ))
    )
  );

-- Super admins full access
CREATE POLICY "Super admins can manage all slots"
  ON availability_slots FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ============================================================================
-- SECTION 10: Create helpful views for compatibility
-- ============================================================================

-- Create a view that shows the effective organization for each slot
CREATE OR REPLACE VIEW availability_slots_with_org AS
SELECT 
  a.*,
  COALESCE(a.organization_id, f.organization_id) as effective_org_id
FROM availability_slots a
LEFT JOIN facilities f ON f.id = a.facility_id;

-- Grant access to the view
GRANT SELECT ON availability_slots_with_org TO authenticated;
GRANT SELECT ON availability_slots_with_org TO anon;
