-- Migration: Complete schema fix for bookings and related tables
-- Date: 2026-01-15 17:00:00
-- This migration safely adds all missing tables and columns

-- ============================================================================
-- SECTION 1: Add missing column to users table
-- ============================================================================

-- Add organization_id to users if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE users ADD COLUMN organization_id UUID NULL;
    ALTER TABLE users ADD CONSTRAINT users_organization_id_fkey 
      FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
    CREATE INDEX idx_users_organization_id ON users(organization_id);
  END IF;
END $$;

-- ============================================================================
-- SECTION 2: Create availability_slots table
-- ============================================================================

CREATE TABLE IF NOT EXISTS availability_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  exam_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE RESTRICT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  is_available BOOLEAN DEFAULT TRUE NOT NULL,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  staff_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_availability_slots_facility ON availability_slots(facility_id);
CREATE INDEX IF NOT EXISTS idx_availability_slots_exam ON availability_slots(exam_id);
CREATE INDEX IF NOT EXISTS idx_availability_slots_start_time ON availability_slots(start_time);
CREATE INDEX IF NOT EXISTS idx_availability_slots_is_available ON availability_slots(is_available);
CREATE INDEX IF NOT EXISTS idx_availability_slots_staff_user ON availability_slots(staff_user_id);

-- ============================================================================
-- SECTION 3: Create facility_exam_offerings table
-- ============================================================================

CREATE TABLE IF NOT EXISTS facility_exam_offerings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  exam_type_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
  price DOUBLE PRECISION NOT NULL DEFAULT 0,
  ssn_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  duration_minutes INTEGER NOT NULL DEFAULT 30,
  preparation_notes TEXT,
  is_available BOOLEAN DEFAULT TRUE NOT NULL,
  max_daily_bookings INTEGER NOT NULL DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(facility_id, exam_type_id)
);

CREATE INDEX IF NOT EXISTS idx_facility_exam_offerings_facility ON facility_exam_offerings(facility_id);
CREATE INDEX IF NOT EXISTS idx_facility_exam_offerings_exam ON facility_exam_offerings(exam_type_id);

-- ============================================================================
-- SECTION 4: Create tariffs table
-- ============================================================================

CREATE TABLE IF NOT EXISTS tariffs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  exam_type_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
  base_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  urgent_surcharge DOUBLE PRECISION NOT NULL DEFAULT 0,
  very_urgent_surcharge DOUBLE PRECISION NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(organization_id, exam_type_id)
);

CREATE INDEX IF NOT EXISTS idx_tariffs_organization ON tariffs(organization_id);
CREATE INDEX IF NOT EXISTS idx_tariffs_exam ON tariffs(exam_type_id);

-- ============================================================================
-- SECTION 5: Create audit_logs table
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  table_name TEXT NOT NULL,
  record_id UUID NULL,
  changes JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- ============================================================================
-- SECTION 6: Add missing columns to bookings table
-- ============================================================================

-- Add slot_id column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' AND column_name = 'slot_id'
  ) THEN
    ALTER TABLE bookings ADD COLUMN slot_id UUID NULL;
    -- Add FK constraint only after availability_slots exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'availability_slots') THEN
      ALTER TABLE bookings ADD CONSTRAINT bookings_slot_id_fkey 
        FOREIGN KEY (slot_id) REFERENCES availability_slots(id) ON DELETE SET NULL;
    END IF;
    CREATE INDEX idx_bookings_slot_id ON bookings(slot_id);
  END IF;
END $$;

-- Add confirmed_by column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' AND column_name = 'confirmed_by'
  ) THEN
    ALTER TABLE bookings ADD COLUMN confirmed_by UUID NULL REFERENCES users(id) ON DELETE SET NULL;
    CREATE INDEX idx_bookings_confirmed_by ON bookings(confirmed_by);
  END IF;
END $$;

-- Add confirmed_at column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' AND column_name = 'confirmed_at'
  ) THEN
    ALTER TABLE bookings ADD COLUMN confirmed_at TIMESTAMPTZ NULL;
  END IF;
END $$;

-- Add operator_notes column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' AND column_name = 'operator_notes'
  ) THEN
    ALTER TABLE bookings ADD COLUMN operator_notes TEXT NULL;
  END IF;
END $$;

-- Add rejected_reason column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' AND column_name = 'rejected_reason'
  ) THEN
    ALTER TABLE bookings ADD COLUMN rejected_reason TEXT NULL;
  END IF;
END $$;

-- Create index for facility_id if not exists
CREATE INDEX IF NOT EXISTS idx_bookings_facility_id ON bookings(facility_id);

-- ============================================================================
-- SECTION 7: Update bookings status constraint
-- ============================================================================

DO $$
BEGIN
  -- Drop old constraint if exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'bookings_status_check'
  ) THEN
    ALTER TABLE bookings DROP CONSTRAINT bookings_status_check;
  END IF;
  
  -- Add new constraint with all statuses
  ALTER TABLE bookings ADD CONSTRAINT bookings_status_check 
    CHECK (status IN ('requested', 'confirmed', 'rejected', 'cancelled', 'completed'));
END $$;

-- ============================================================================
-- SECTION 8: Enable RLS on new tables
-- ============================================================================

ALTER TABLE availability_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_exam_offerings ENABLE ROW LEVEL SECURITY;
ALTER TABLE tariffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SECTION 9: RLS Policies for availability_slots
-- ============================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Public can view available slots" ON availability_slots;
DROP POLICY IF EXISTS "Org admins can view org slots" ON availability_slots;
DROP POLICY IF EXISTS "Org admins can manage org slots" ON availability_slots;
DROP POLICY IF EXISTS "Super admins can manage all slots" ON availability_slots;

-- Public can view available slots
CREATE POLICY "Public can view available slots"
  ON availability_slots FOR SELECT
  USING (is_available = true AND is_active = true);

-- Org admins can view all slots for their organization's facilities
CREATE POLICY "Org admins can view org slots"
  ON availability_slots FOR SELECT TO authenticated
  USING (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = availability_slots.facility_id 
        AND f.organization_id = u.organization_id
    )
  );

-- Org admins can manage slots for their organization's facilities
CREATE POLICY "Org admins can manage org slots"
  ON availability_slots FOR ALL TO authenticated
  USING (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = availability_slots.facility_id 
        AND f.organization_id = u.organization_id
    )
  )
  WITH CHECK (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = availability_slots.facility_id 
        AND f.organization_id = u.organization_id
    )
  );

-- Super admins full access
CREATE POLICY "Super admins can manage all slots"
  ON availability_slots FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ============================================================================
-- SECTION 10: RLS Policies for facility_exam_offerings
-- ============================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Public can view exam offerings" ON facility_exam_offerings;
DROP POLICY IF EXISTS "Org admins can manage org offerings" ON facility_exam_offerings;
DROP POLICY IF EXISTS "Super admins can manage all offerings" ON facility_exam_offerings;

-- Public can view available offerings
CREATE POLICY "Public can view exam offerings"
  ON facility_exam_offerings FOR SELECT
  USING (true);

-- Org admins can manage offerings for their facilities
CREATE POLICY "Org admins can manage org offerings"
  ON facility_exam_offerings FOR ALL TO authenticated
  USING (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = facility_exam_offerings.facility_id 
        AND f.organization_id = u.organization_id
    )
  )
  WITH CHECK (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = facility_exam_offerings.facility_id 
        AND f.organization_id = u.organization_id
    )
  );

-- Super admins full access
CREATE POLICY "Super admins can manage all offerings"
  ON facility_exam_offerings FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ============================================================================
-- SECTION 11: RLS Policies for tariffs
-- ============================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Authenticated can view tariffs" ON tariffs;
DROP POLICY IF EXISTS "Org admins can manage org tariffs" ON tariffs;
DROP POLICY IF EXISTS "Super admins can manage all tariffs" ON tariffs;

-- Authenticated users can view tariffs
CREATE POLICY "Authenticated can view tariffs"
  ON tariffs FOR SELECT TO authenticated
  USING (true);

-- Org admins can manage their organization tariffs
CREATE POLICY "Org admins can manage org tariffs"
  ON tariffs FOR ALL TO authenticated
  USING (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM users u 
      WHERE u.auth_user_id = auth.uid() 
        AND u.organization_id = tariffs.organization_id
    )
  )
  WITH CHECK (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM users u 
      WHERE u.auth_user_id = auth.uid() 
        AND u.organization_id = tariffs.organization_id
    )
  );

-- Super admins full access
CREATE POLICY "Super admins can manage all tariffs"
  ON tariffs FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ============================================================================
-- SECTION 12: RLS Policies for audit_logs
-- ============================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Super admins can view audit logs" ON audit_logs;
DROP POLICY IF EXISTS "Service role can insert audit logs" ON audit_logs;

-- Only super admins can view audit logs
CREATE POLICY "Super admins can view audit logs"
  ON audit_logs FOR SELECT TO authenticated
  USING (is_super_admin());

-- System can insert audit logs (via service role)
CREATE POLICY "Service role can insert audit logs"
  ON audit_logs FOR INSERT
  WITH CHECK (true);

-- ============================================================================
-- SECTION 13: Additional bookings policies for org admins
-- ============================================================================

-- Drop existing policies if any
DROP POLICY IF EXISTS "Org admins can update org bookings" ON bookings;
DROP POLICY IF EXISTS "Org admins can create org bookings" ON bookings;

-- Org admins can update bookings for their facilities
CREATE POLICY "Org admins can update org bookings"
  ON bookings FOR UPDATE TO authenticated
  USING (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = bookings.facility_id 
        AND f.organization_id = u.organization_id
    )
  )
  WITH CHECK (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = bookings.facility_id 
        AND f.organization_id = u.organization_id
    )
  );

-- Org admins can insert bookings for their facilities (manual booking)
CREATE POLICY "Org admins can create org bookings"
  ON bookings FOR INSERT TO authenticated
  WITH CHECK (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = bookings.facility_id 
        AND f.organization_id = u.organization_id
    )
  );
