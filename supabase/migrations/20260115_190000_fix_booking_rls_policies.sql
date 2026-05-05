-- Migration: Fix booking RLS policies to allow org_admin inserts
-- Date: 2026-01-15 19:00:00
-- Allows org_admin to create bookings for any user (patient)

-- ============================================================================
-- SECTION 1: Drop existing INSERT policies on bookings
-- ============================================================================

DROP POLICY IF EXISTS "Users can create their own bookings" ON bookings;
DROP POLICY IF EXISTS "Anon can create bookings" ON bookings;
DROP POLICY IF EXISTS "Org admins can create bookings" ON bookings;
DROP POLICY IF EXISTS "Authenticated users can insert bookings" ON bookings;
DROP POLICY IF EXISTS "Anyone can create bookings" ON bookings;
DROP POLICY IF EXISTS "Allow authenticated users to insert bookings" ON bookings;
DROP POLICY IF EXISTS "Allow anon to insert bookings" ON bookings;

-- ============================================================================
-- SECTION 2: Create new INSERT policy that allows authenticated users
-- ============================================================================

-- Policy: Allow all authenticated users to insert bookings
-- This is needed because org_admins create bookings on behalf of patients
CREATE POLICY "Allow authenticated users to insert bookings"
ON bookings FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow anon users to insert bookings (for guest booking flow)
CREATE POLICY "Allow anon to insert bookings"
ON bookings FOR INSERT
TO anon
WITH CHECK (true);

-- ============================================================================
-- SECTION 3: Ensure SELECT policies exist for org_admins
-- ============================================================================

DROP POLICY IF EXISTS "Org admins can view their facility bookings" ON bookings;
CREATE POLICY "Org admins can view their facility bookings"
ON bookings FOR SELECT
TO authenticated
USING (
  facility_id IN (
    SELECT f.id FROM facilities f
    JOIN users u ON u.organization_id = f.organization_id
    WHERE u.id = auth.uid()
    AND u.role IN ('org_admin', 'super_admin')
  )
  OR user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
);

-- ============================================================================
-- SECTION 4: Ensure UPDATE policies exist for org_admins
-- ============================================================================

DROP POLICY IF EXISTS "Org admins can update their facility bookings" ON bookings;
CREATE POLICY "Org admins can update their facility bookings"
ON bookings FOR UPDATE
TO authenticated
USING (
  facility_id IN (
    SELECT f.id FROM facilities f
    JOIN users u ON u.organization_id = f.organization_id
    WHERE u.id = auth.uid()
    AND u.role IN ('org_admin', 'super_admin')
  )
  OR user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
)
WITH CHECK (
  facility_id IN (
    SELECT f.id FROM facilities f
    JOIN users u ON u.organization_id = f.organization_id
    WHERE u.id = auth.uid()
    AND u.role IN ('org_admin', 'super_admin')
  )
  OR user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
);

-- ============================================================================
-- SECTION 5: Ensure DELETE policies exist
-- ============================================================================

DROP POLICY IF EXISTS "Org admins can delete bookings" ON bookings;
CREATE POLICY "Org admins can delete bookings"
ON bookings FOR DELETE
TO authenticated
USING (
  facility_id IN (
    SELECT f.id FROM facilities f
    JOIN users u ON u.organization_id = f.organization_id
    WHERE u.id = auth.uid()
    AND u.role IN ('org_admin', 'super_admin')
  )
  OR user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
);

-- ============================================================================
-- SECTION 6: Create/update the RPC function for booking bypass
-- ============================================================================

-- Drop existing function if exists with all possible signatures
DROP FUNCTION IF EXISTS create_booking_bypass_rls(uuid, uuid, uuid, date, timestamptz, uuid, text, numeric, text);
DROP FUNCTION IF EXISTS create_booking_bypass_rls(uuid, uuid, uuid, text, text, uuid, text, numeric, text);

-- Create the RPC function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION create_booking_bypass_rls(
  p_user_id uuid,
  p_facility_id uuid DEFAULT NULL,
  p_exam_type_id uuid DEFAULT NULL,
  p_booking_date text DEFAULT NULL,
  p_booking_time text DEFAULT NULL,
  p_slot_id uuid DEFAULT NULL,
  p_urgency_level text DEFAULT 'normal',
  p_price numeric DEFAULT 0,
  p_notes text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking_id uuid;
  v_booking json;
  v_now timestamptz := NOW();
  v_booking_date date;
  v_booking_time timestamptz;
BEGIN
  -- Parse date and time from text
  v_booking_date := COALESCE(p_booking_date::date, CURRENT_DATE);
  v_booking_time := COALESCE(p_booking_time::timestamptz, NOW());

  -- Check if slot is available (if provided)
  IF p_slot_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM availability_slots 
      WHERE id = p_slot_id 
      AND is_available = true 
      AND is_active = true
    ) THEN
      RAISE EXCEPTION 'Slot non disponibile o già prenotato';
    END IF;
  END IF;

  -- Generate new UUID for booking
  v_booking_id := gen_random_uuid();

  -- Insert booking
  INSERT INTO bookings (
    id,
    user_id,
    facility_id,
    exam_type_id,
    booking_date,
    booking_time,
    slot_id,
    urgency_level,
    price,
    notes,
    status,
    needs_transport,
    is_home_service,
    created_at,
    updated_at
  ) VALUES (
    v_booking_id,
    p_user_id,
    p_facility_id,
    p_exam_type_id,
    v_booking_date,
    v_booking_time,
    p_slot_id,
    COALESCE(p_urgency_level, 'normal'),
    COALESCE(p_price, 0),
    p_notes,
    'requested',
    false,
    false,
    v_now,
    v_now
  );

  -- Mark slot as unavailable if provided
  IF p_slot_id IS NOT NULL THEN
    UPDATE availability_slots 
    SET is_available = false, 
        is_active = false,
        updated_at = v_now
    WHERE id = p_slot_id;
  END IF;

  -- Return the created booking as JSON
  SELECT row_to_json(b.*) INTO v_booking
  FROM bookings b
  WHERE b.id = v_booking_id;

  RETURN v_booking;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION create_booking_bypass_rls TO authenticated;
GRANT EXECUTE ON FUNCTION create_booking_bypass_rls TO anon;

-- Add comment
COMMENT ON FUNCTION create_booking_bypass_rls IS 
'Creates a booking bypassing RLS. Used by org_admins to create bookings for patients.';

-- ============================================================================
-- DONE
-- ============================================================================
SELECT 'Migration completed successfully: Booking RLS policies fixed' as status;
