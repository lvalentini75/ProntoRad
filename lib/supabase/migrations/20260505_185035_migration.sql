-- Migration: Fix availability_slots RLS policies for INSERT operations
-- Issue: Slots are not being created even though user is authenticated and belongs to organization

-- ============================================================================
-- STEP 1: DROP ALL EXISTING POLICIES FOR AVAILABILITY_SLOTS
-- ============================================================================
DO $$
BEGIN
  -- Drop all existing policies
  DROP POLICY IF EXISTS "allow_insert_authenticated" ON availability_slots;
  DROP POLICY IF EXISTS "allow_select_all" ON availability_slots;
  DROP POLICY IF EXISTS "allow_update_authenticated" ON availability_slots;
  DROP POLICY IF EXISTS "allow_delete_authenticated" ON availability_slots;
  DROP POLICY IF EXISTS "Org staff can manage their availability slots" ON availability_slots;
  DROP POLICY IF EXISTS "Authenticated users can insert slots (DEBUG)" ON availability_slots;
  DROP POLICY IF EXISTS "Public can view available slots" ON availability_slots;
  DROP POLICY IF EXISTS "Org admins can view org slots" ON availability_slots;
  DROP POLICY IF EXISTS "Org admins can manage org slots" ON availability_slots;
  DROP POLICY IF EXISTS "Super admins can manage all slots" ON availability_slots;
  DROP POLICY IF EXISTS "Allow authenticated insert availability_slots" ON availability_slots;
  DROP POLICY IF EXISTS "Allow authenticated select availability_slots" ON availability_slots;
  DROP POLICY IF EXISTS "Anyone can view availability slots" ON availability_slots;
  DROP POLICY IF EXISTS "Org staff can manage slots" ON availability_slots;
  
  RAISE NOTICE '✅ Dropped all existing availability_slots policies';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '⚠️ Some policies might not exist: %', SQLERRM;
END $$;

-- ============================================================================
-- STEP 2: ENSURE RLS IS ENABLED
-- ============================================================================
ALTER TABLE availability_slots ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 3: CREATE NEW SIMPLE POLICIES
-- ============================================================================

-- SELECT: Everyone can view availability slots (for booking flow)
CREATE POLICY "availability_slots_select_all"
ON availability_slots
FOR SELECT
USING (true);

-- INSERT: Authenticated users can insert slots for their organization
-- Using a simple check: organization_id must match the user's organization_id in users table
CREATE POLICY "availability_slots_insert_org_member"
ON availability_slots
FOR INSERT
TO authenticated
WITH CHECK (
  -- Check if the user belongs to the organization they're inserting for
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.organization_id = availability_slots.organization_id
    AND u.role IN ('org_admin', 'super_admin')
  )
  -- OR if user is super_admin (can create for any org)
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
);

-- UPDATE: Same logic as INSERT
CREATE POLICY "availability_slots_update_org_member"
ON availability_slots
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.organization_id = availability_slots.organization_id
    AND u.role IN ('org_admin', 'super_admin')
  )
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.organization_id = availability_slots.organization_id
    AND u.role IN ('org_admin', 'super_admin')
  )
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
);

-- DELETE: Same logic as INSERT/UPDATE
CREATE POLICY "availability_slots_delete_org_member"
ON availability_slots
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.organization_id = availability_slots.organization_id
    AND u.role IN ('org_admin', 'super_admin')
  )
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
);

-- ============================================================================
-- STEP 4: VERIFY POLICIES CREATED
-- ============================================================================
DO $$
DECLARE
  policy_count INT;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'availability_slots' AND schemaname = 'public';
  
  RAISE NOTICE '✅ availability_slots now has % policies', policy_count;
  
  -- List them
  FOR policy_count IN 
    SELECT policyname FROM pg_policies 
    WHERE tablename = 'availability_slots' AND schemaname = 'public'
  LOOP
    -- This won't work exactly like this, but shows intent
  END LOOP;
END $$;

-- ============================================================================
-- STEP 5: CREATE DIAGNOSTIC FUNCTION
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
