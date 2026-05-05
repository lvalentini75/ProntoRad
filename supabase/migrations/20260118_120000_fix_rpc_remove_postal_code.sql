-- Fix RPC function: remove postal_code which doesn't exist in organizations table
-- This fixes the "column o.postal_code does not exist" error

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
    'needs_transport', b.needs_transport,
    'is_home_service', b.is_home_service,
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
        'first_name', u.first_name,
        'last_name', u.last_name,
        'email', u.email,
        'phone_number', u.phone_number,
        'date_of_birth', u.date_of_birth,
        'fiscal_code', u.fiscal_code,
        'role', u.role,
        'organization_id', u.organization_id,
        'created_at', u.created_at,
        'updated_at', u.updated_at
      )
      ELSE NULL
    END,
    'exam_type', CASE 
      WHEN e.id IS NOT NULL THEN json_build_object(
        'id', e.id,
        'name', e.name,
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
        'name', o.name,
        'org_type', o.org_type,
        'address', o.address,
        'city', o.city,
        'province', o.province,
        'region', o.region,
        'latitude', o.latitude,
        'longitude', o.longitude,
        'phone', o.phone,
        'email', o.email,
        'website', o.website,
        'vat_number', o.vat_number,
        'logo_url', o.logo_url,
        'notes', o.notes,
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

-- Grant execute permission to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION public.get_booking_with_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_booking_with_user(uuid) TO anon;

-- Add helpful comment
COMMENT ON FUNCTION public.get_booking_with_user IS 'Retrieves booking with joined user, exam type, and organization data, bypassing RLS policies';
