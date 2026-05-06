-- ============================================================================
-- Migration: DEFINITIVE FIX for availability_slots RLS policies
-- Date: 2026-05-05
-- Problem: Slots appear to be created but are not saved to database
-- Root cause: Conflicting RLS policies blocking INSERT operations
-- Solution: Drop ALL existing policies and create simple, working ones
-- ============================================================================

-- STEP 1: Drop ALL existing policies on availability_slots
-- ============================================================================
DO $$
DECLARE
  policy_rec RECORD;
  drop_count INT := 0;
BEGIN
  RAISE NOTICE '🗑️ Dropping all existing policies on availability_slots...';
  
  FOR policy_rec IN
    SELECT policyname 
    FROM pg_policies 
    WHERE tablename = 'availability_slots' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON availability_slots', policy_rec.policyname);
    drop_count := drop_count + 1;
    RAISE NOTICE '   ❌ Dropped: %', policy_rec.policyname;
  END LOOP;
  
  RAISE NOTICE '✅ Dropped % policies total', drop_count;
END $$;

-- STEP 2: Ensure RLS is enabled
-- ============================================================================
ALTER TABLE availability_slots ENABLE ROW LEVEL SECURITY;

-- STEP 3: Create simple, working policies
-- ============================================================================

-- SELECT: Anyone can view slots (needed for booking flow)
CREATE POLICY "avail_slots_select_all"
ON availability_slots
FOR SELECT
USING (true);

-- INSERT: Authenticated users with org_admin or super_admin role can insert
-- Uses simple subquery to check user role and organization match
CREATE POLICY "avail_slots_insert_admin"
ON availability_slots
FOR INSERT
TO authenticated
WITH CHECK (
  -- Super admin can insert for any organization
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
  OR
  -- Org admin can insert only for their organization
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'org_admin'
    AND u.organization_id = availability_slots.organization_id
  )
);

-- UPDATE: Same logic as INSERT
CREATE POLICY "avail_slots_update_admin"
ON availability_slots
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
  OR
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'org_admin'
    AND u.organization_id = availability_slots.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
  OR
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'org_admin'
    AND u.organization_id = availability_slots.organization_id
  )
);

-- DELETE: Same logic as INSERT/UPDATE
CREATE POLICY "avail_slots_delete_admin"
ON availability_slots
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'super_admin'
  )
  OR
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.auth_user_id = auth.uid()
    AND u.role = 'org_admin'
    AND u.organization_id = availability_slots.organization_id
  )
);

-- STEP 4: Create/update debug function to verify INSERT permission
-- ============================================================================
CREATE OR REPLACE FUNCTION debug_user_can_insert_slot(p_organization_id UUID)
RETURNS TABLE (
  can_insert BOOLEAN,
  auth_uid UUID,
  user_email TEXT,
  user_role TEXT,
  user_org_id UUID,
  target_org_id UUID,
  org_matches BOOLEAN,
  has_admin_role BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    -- Can insert if super_admin OR (org_admin AND org matches)
    (u.role = 'super_admin' OR (u.role = 'org_admin' AND u.organization_id = p_organization_id)) AS can_insert,
    auth.uid() AS auth_uid,
    u.email AS user_email,
    u.role AS user_role,
    u.organization_id AS user_org_id,
    p_organization_id AS target_org_id,
    (u.organization_id = p_organization_id) AS org_matches,
    (u.role IN ('org_admin', 'super_admin')) AS has_admin_role
  FROM users u
  WHERE u.auth_user_id = auth.uid();
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION debug_user_can_insert_slot(UUID) TO authenticated;

-- STEP 5: Verify the new policies were created
-- ============================================================================
DO $$
DECLARE
  policy_count INT;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'availability_slots' AND schemaname = 'public';
  
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '✅ MIGRATION COMPLETED';
  RAISE NOTICE '   - availability_slots now has % RLS policies', policy_count;
  RAISE NOTICE '   - Policies: avail_slots_select_all, avail_slots_insert_admin,';
  RAISE NOTICE '               avail_slots_update_admin, avail_slots_delete_admin';
  RAISE NOTICE '   - Debug function: debug_user_can_insert_slot(org_id)';
  RAISE NOTICE '============================================================';
END $$;
