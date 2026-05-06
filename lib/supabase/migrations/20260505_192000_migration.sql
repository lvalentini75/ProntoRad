-- Migration: Fix function creation (final attempt)
-- Previous migration created RLS policies successfully but failed at verification
-- This migration ONLY creates the missing diagnostic function without verification loops

-- ============================================================================
-- DROP EXISTING FUNCTION IF EXISTS (cleanup)
-- ============================================================================
DROP FUNCTION IF EXISTS public.debug_user_can_insert_slot(UUID);

-- ============================================================================
-- CREATE DIAGNOSTIC FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.debug_user_can_insert_slot(p_organization_id UUID)
RETURNS TABLE (
  can_insert BOOLEAN,
  auth_uid UUID,
  user_id UUID,
  user_email TEXT,
  user_role TEXT,
  user_org_id UUID,
  target_org_id UUID,
  org_matches BOOLEAN,
  has_admin_role BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid UUID;
  v_user_id UUID;
  v_user_email TEXT;
  v_user_role TEXT;
  v_user_org_id UUID;
BEGIN
  -- Get current auth user
  v_auth_uid := auth.uid();
  
  -- Get user info from users table
  SELECT u.id, u.email, u.role, u.organization_id
  INTO v_user_id, v_user_email, v_user_role, v_user_org_id
  FROM public.users u
  WHERE u.auth_user_id = v_auth_uid
  LIMIT 1;
  
  RETURN QUERY SELECT
    -- can_insert: user must be admin of target org OR be super_admin
    (v_user_org_id = p_organization_id AND v_user_role IN ('org_admin', 'super_admin'))
    OR (v_user_role = 'super_admin'),
    -- auth_uid
    v_auth_uid,
    -- user_id
    v_user_id,
    -- user_email
    v_user_email,
    -- user_role
    v_user_role,
    -- user_org_id
    v_user_org_id,
    -- target_org_id
    p_organization_id,
    -- org_matches
    (v_user_org_id = p_organization_id),
    -- has_admin_role
    (v_user_role IN ('org_admin', 'super_admin'));
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.debug_user_can_insert_slot(UUID) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.debug_user_can_insert_slot IS 'Debug function to check if current user can insert slots for an organization';

-- ============================================================================
-- SIMPLE VERIFICATION (no loops, just a notice)
-- ============================================================================
DO $$
DECLARE
  v_function_exists BOOLEAN;
BEGIN
  -- Check if function exists
  SELECT EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'debug_user_can_insert_slot' 
    AND pronamespace = 'public'::regnamespace
  ) INTO v_function_exists;
  
  IF v_function_exists THEN
    RAISE NOTICE '✅ Function debug_user_can_insert_slot created successfully';
  ELSE
    RAISE WARNING '❌ Function debug_user_can_insert_slot NOT found';
  END IF;
END $$;
