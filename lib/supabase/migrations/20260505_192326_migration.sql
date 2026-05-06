-- =====================================================
-- FIX: Drop and recreate debug_user_can_insert_slot function
-- The function signature changed, so we need to drop it first
-- =====================================================

-- Step 1: Drop the existing function (with all its signatures)
DROP FUNCTION IF EXISTS debug_user_can_insert_slot(uuid);
DROP FUNCTION IF EXISTS debug_user_can_insert_slot();

-- Step 2: Recreate the function with correct signature
CREATE OR REPLACE FUNCTION debug_user_can_insert_slot(check_user_id uuid DEFAULT NULL)
RETURNS TABLE(
  user_id uuid,
  user_email text,
  user_role text,
  user_org_id uuid,
  can_insert boolean,
  reason text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_email text;
  v_role text;
  v_org_id uuid;
  v_can_insert boolean := false;
  v_reason text := '';
BEGIN
  -- Use provided user_id or current auth user
  v_user_id := COALESCE(check_user_id, auth.uid());
  
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 
      NULL::uuid,
      'N/A'::text,
      'N/A'::text,
      NULL::uuid,
      false,
      'No user authenticated'::text;
    RETURN;
  END IF;
  
  -- Get user profile
  SELECT p.email, p.role, p.organization_id
  INTO v_email, v_role, v_org_id
  FROM profiles p
  WHERE p.id = v_user_id;
  
  IF v_email IS NULL THEN
    RETURN QUERY SELECT 
      v_user_id,
      'NOT FOUND'::text,
      'N/A'::text,
      NULL::uuid,
      false,
      'Profile not found for this user_id'::text;
    RETURN;
  END IF;
  
  -- Check permissions
  IF v_role = 'super_admin' THEN
    v_can_insert := true;
    v_reason := 'User is super_admin - can insert any slot';
  ELSIF v_role = 'org_admin' THEN
    IF v_org_id IS NOT NULL THEN
      v_can_insert := true;
      v_reason := 'User is org_admin with organization_id - can insert slots for their org';
    ELSE
      v_can_insert := false;
      v_reason := 'User is org_admin but has NO organization_id - cannot insert slots';
    END IF;
  ELSE
    v_can_insert := false;
    v_reason := 'User role is "' || COALESCE(v_role, 'NULL') || '" - only org_admin or super_admin can insert slots';
  END IF;
  
  RETURN QUERY SELECT 
    v_user_id,
    v_email,
    v_role,
    v_org_id,
    v_can_insert,
    v_reason;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION debug_user_can_insert_slot(uuid) TO authenticated;

-- Verification message
DO $$
BEGIN
  RAISE NOTICE '✅ Function debug_user_can_insert_slot recreated successfully';
END $$;
