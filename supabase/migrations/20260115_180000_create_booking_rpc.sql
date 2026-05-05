-- Migration: Create RPC function for booking creation that bypasses RLS
-- Date: 2026-01-15 18:00:00
-- This function runs with SECURITY DEFINER to bypass RLS policies
-- Allows org_admins to create bookings for patients

-- Drop existing function if exists
DROP FUNCTION IF EXISTS create_booking_bypass_rls(
  uuid, uuid, uuid, date, timestamptz, uuid, text, numeric, text
);

-- Create the RPC function with SECURITY DEFINER
CREATE OR REPLACE FUNCTION create_booking_bypass_rls(
  p_user_id uuid,
  p_facility_id uuid DEFAULT NULL,
  p_exam_type_id uuid DEFAULT NULL,
  p_booking_date date DEFAULT CURRENT_DATE,
  p_booking_time timestamptz DEFAULT NOW(),
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
BEGIN
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
    p_booking_date,
    p_booking_time,
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
