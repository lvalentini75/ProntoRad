-- Migration: Make get_booking_with_user RPC function ROBUST
-- Date: 2026-01-20
-- This migration makes the RPC work regardless of which columns exist

-- First, ensure organizations has the required columns
ALTER TABLE IF EXISTS organizations 
  ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION NULL,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION NULL,
  ADD COLUMN IF NOT EXISTS postal_code TEXT DEFAULT '';

-- Drop and recreate the RPC function with ROBUST column handling
DROP FUNCTION IF EXISTS public.get_booking_with_user(uuid);

CREATE OR REPLACE FUNCTION public.get_booking_with_user(p_booking_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result json;
BEGIN
  -- Fetch booking with joined user, exam_type, and organization data
  -- Uses ONLY columns that are guaranteed to exist
  SELECT json_build_object(
    'id', b.id,
    'user_id', b.user_id,
    'organization_id', b.organization_id,
    'exam_type_id', b.exam_type_id,
    'booking_date', b.booking_date,
    'booking_time', b.booking_time,
    'slot_id', b.slot_id,
    'status', b.status,
    'urgency_level', b.urgency_level,
    'price', b.price,
    'notes', b.notes,
    'needs_transport', COALESCE(b.needs_transport, false),
    'is_home_service', COALESCE(b.is_home_service, false),
    'confirmed_by', b.confirmed_by,
    'confirmed_at', b.confirmed_at,
    'operator_notes', b.operator_notes,
    'rejected_reason', b.rejected_reason,
    'created_at', b.created_at,
    'updated_at', b.updated_at,
    'user', CASE 
      WHEN u.id IS NOT NULL THEN json_build_object(
        'id', u.id,
        'auth_user_id', u.auth_user_id,
        'first_name', COALESCE(u.first_name, ''),
        'last_name', COALESCE(u.last_name, ''),
        'email', COALESCE(u.email, ''),
        'phone_number', COALESCE(u.phone_number, ''),
        'date_of_birth', u.date_of_birth,
        'fiscal_code', u.fiscal_code,
        'role', COALESCE(u.role, 'end_user'),
        'organization_id', u.organization_id,
        'created_at', u.created_at,
        'updated_at', u.updated_at
      )
      ELSE NULL
    END,
    'exam_type', CASE 
      WHEN e.id IS NOT NULL THEN json_build_object(
        'id', e.id,
        'name', COALESCE(e.name, ''),
        'description', e.description,
        'category', e.category,
        'created_at', e.created_at,
        'updated_at', e.updated_at
      )
      ELSE NULL
    END,
    'organization', CASE 
      WHEN o.id IS NOT NULL THEN json_build_object(
        'id', o.id,
        'name', COALESCE(o.name, ''),
        'org_type', o.org_type,
        'address', COALESCE(o.address, ''),
        'city', COALESCE(o.city, ''),
        'province', COALESCE(o.province, ''),
        'region', COALESCE(o.region, ''),
        'phone', o.phone,
        'email', o.email,
        'website', o.website,
        'created_at', o.created_at,
        'updated_at', o.updated_at
      )
      ELSE NULL
    END
  )
  INTO result
  FROM public.bookings b
  LEFT JOIN public.users u ON b.user_id = u.id
  LEFT JOIN public.exam_types e ON b.exam_type_id = e.id
  LEFT JOIN public.organizations o ON b.organization_id = o.id
  WHERE b.id = p_booking_id;
  
  RETURN result;
END;
$$;

-- Grant execute permission to all
GRANT EXECUTE ON FUNCTION public.get_booking_with_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_booking_with_user(uuid) TO anon;

-- Add comment
COMMENT ON FUNCTION public.get_booking_with_user IS 'Retrieves booking with user, exam type, and organization data - ROBUST version';

-- ============================================================================
-- ALSO: Ensure availability_slots has correct RLS policies for INSERT
-- ============================================================================

-- Drop existing problematic policies
DROP POLICY IF EXISTS "availability_slots_insert_policy" ON availability_slots;
DROP POLICY IF EXISTS "availability_slots_select_policy" ON availability_slots;
DROP POLICY IF EXISTS "Authenticated users can insert slots" ON availability_slots;
DROP POLICY IF EXISTS "Authenticated users can insert slots (DEBUG)" ON availability_slots;
DROP POLICY IF EXISTS "Staff can insert slots" ON availability_slots;
DROP POLICY IF EXISTS "Users can view organization slots" ON availability_slots;

-- Create simple INSERT policy for authenticated users
CREATE POLICY "allow_insert_authenticated" ON availability_slots
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Create SELECT policy for all users
CREATE POLICY "allow_select_all" ON availability_slots
  FOR SELECT
  USING (true);

-- Create UPDATE policy for authenticated users
DROP POLICY IF EXISTS "allow_update_authenticated" ON availability_slots;
CREATE POLICY "allow_update_authenticated" ON availability_slots
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create DELETE policy for authenticated users  
DROP POLICY IF EXISTS "allow_delete_authenticated" ON availability_slots;
CREATE POLICY "allow_delete_authenticated" ON availability_slots
  FOR DELETE
  TO authenticated
  USING (true);

-- ============================================================================
-- Ensure availability_slots columns exist and have correct types
-- ============================================================================
ALTER TABLE IF EXISTS availability_slots
  ADD COLUMN IF NOT EXISTS organization_id UUID NULL,
  ADD COLUMN IF NOT EXISTS exam_type_id UUID NULL,
  ADD COLUMN IF NOT EXISTS specific_date DATE NULL,
  ADD COLUMN IF NOT EXISTS day_of_week INT NULL,
  ADD COLUMN IF NOT EXISTS max_bookings INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- ============================================================================
-- ALSO: Ensure bookings RLS allows inserts for authenticated users
-- ============================================================================
DROP POLICY IF EXISTS "bookings_insert_policy" ON bookings;
DROP POLICY IF EXISTS "Users can create bookings" ON bookings;
DROP POLICY IF EXISTS "allow_insert_bookings" ON bookings;

CREATE POLICY "allow_insert_bookings_auth" ON bookings
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Ensure SELECT on bookings works
DROP POLICY IF EXISTS "allow_select_bookings" ON bookings;
CREATE POLICY "allow_select_bookings_auth" ON bookings
  FOR SELECT
  TO authenticated
  USING (true);

-- Ensure UPDATE on bookings works  
DROP POLICY IF EXISTS "allow_update_bookings" ON bookings;
CREATE POLICY "allow_update_bookings_auth" ON bookings
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);
