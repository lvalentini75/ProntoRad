-- Migration: Use organization_id directly in bookings instead of facility_id
-- Date: 2026-01-16 10:00:00
-- This migration makes facility_id optional and adds organization_id to bookings
-- Reason: In this app, "Struttura" and "Organizzazione" are the same concept

-- ============================================================================
-- SECTION 1: Add organization_id to bookings table
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE bookings ADD COLUMN organization_id UUID NULL;
    ALTER TABLE bookings ADD CONSTRAINT bookings_organization_id_fkey 
      FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
    CREATE INDEX idx_bookings_organization_id ON bookings(organization_id);
  END IF;
END $$;

-- ============================================================================
-- SECTION 2: Make facility_id nullable (if it isn't already)
-- ============================================================================

DO $$
BEGIN
  -- First drop the NOT NULL constraint if exists
  ALTER TABLE bookings ALTER COLUMN facility_id DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN
    -- Already nullable, ignore
    NULL;
END $$;

-- ============================================================================
-- SECTION 3: Backfill organization_id from facility where possible
-- ============================================================================

UPDATE bookings b
SET organization_id = f.organization_id
FROM facilities f
WHERE b.facility_id = f.id
  AND b.organization_id IS NULL
  AND f.organization_id IS NOT NULL;

-- ============================================================================
-- SECTION 4: Update RLS policies for bookings to use organization_id
-- ============================================================================

-- Drop old policies that require facility_id
DROP POLICY IF EXISTS "Org admins can update org bookings" ON bookings;
DROP POLICY IF EXISTS "Org admins can create org bookings" ON bookings;
DROP POLICY IF EXISTS "Org admins can view org bookings" ON bookings;

-- Create new policies using organization_id OR facility_id
CREATE POLICY "Org admins can view org bookings"
  ON bookings FOR SELECT TO authenticated
  USING (
    is_org_admin() AND (
      -- Match by organization_id directly
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = bookings.organization_id
      )
      OR
      -- Fallback: match by facility_id -> organization
      (bookings.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = bookings.facility_id 
          AND f.organization_id = u.organization_id
      ))
    )
  );

CREATE POLICY "Org admins can update org bookings"
  ON bookings FOR UPDATE TO authenticated
  USING (
    is_org_admin() AND (
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = bookings.organization_id
      )
      OR
      (bookings.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = bookings.facility_id 
          AND f.organization_id = u.organization_id
      ))
    )
  )
  WITH CHECK (
    is_org_admin() AND (
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = bookings.organization_id
      )
      OR
      (bookings.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = bookings.facility_id 
          AND f.organization_id = u.organization_id
      ))
    )
  );

CREATE POLICY "Org admins can create org bookings"
  ON bookings FOR INSERT TO authenticated
  WITH CHECK (
    is_org_admin() AND (
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = bookings.organization_id
      )
      OR
      (bookings.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = bookings.facility_id 
          AND f.organization_id = u.organization_id
      ))
    )
  );

-- ============================================================================
-- SECTION 5: Add policy for deleting bookings
-- ============================================================================

DROP POLICY IF EXISTS "Org admins can delete org bookings" ON bookings;
CREATE POLICY "Org admins can delete org bookings"
  ON bookings FOR DELETE TO authenticated
  USING (
    is_org_admin() AND (
      EXISTS (
        SELECT 1 FROM users u 
        WHERE u.auth_user_id = auth.uid() 
          AND u.organization_id = bookings.organization_id
      )
      OR
      (bookings.facility_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM facilities f
        JOIN users u ON u.auth_user_id = auth.uid()
        WHERE f.id = bookings.facility_id 
          AND f.organization_id = u.organization_id
      ))
    )
  );
