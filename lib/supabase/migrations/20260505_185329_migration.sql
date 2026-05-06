-- Migration: Fix - Create debug function that failed in previous migration
-- Previous migration 20260505_185035 failed at STEP 4 (verification DO block)
-- Policies were created successfully, only the debug function is missing

-- ============================================================================
-- CREATE DIAGNOSTIC FUNCTION (was not created due to previous failure)
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
    -- can_insert
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

GRANT EXECUTE ON FUNCTION public.debug_user_can_insert_slot(UUID) TO authenticated;

COMMENT ON FUNCTION public.debug_user_can_insert_slot IS 'Debug function to check if current user can insert slots for a given organization. Call with: SELECT * FROM debug_user_can_insert_slot(''org-uuid-here'');';
