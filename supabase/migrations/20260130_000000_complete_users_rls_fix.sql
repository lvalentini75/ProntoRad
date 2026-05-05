-- ============================================================================
-- COMPLETE FIX FOR USERS TABLE RLS POLICIES - ELIMINATE ALL RECURSION
-- ============================================================================
-- This migration REMOVES ALL existing policies on the users table and creates
-- fresh, simple policies that DO NOT cause infinite recursion.
--
-- The key insight: NEVER query the `users` table within a policy on `users`!
-- Instead, use the `users_internal` view which bypasses RLS.
-- ============================================================================

-- ============================================================================
-- STEP 0: Ensure users_internal view exists with SECURITY DEFINER
-- ============================================================================

-- First, drop and recreate users_internal with proper security
DROP VIEW IF EXISTS users_internal CASCADE;

-- Create view that bypasses RLS (SECURITY DEFINER means it runs as the owner)
CREATE VIEW users_internal 
WITH (security_invoker = false)
AS SELECT * FROM users;

-- Grant access to authenticated users
GRANT SELECT ON users_internal TO authenticated;

-- ============================================================================
-- STEP 1: DROP ALL EXISTING POLICIES ON USERS TABLE
-- ============================================================================

-- Drop all known policies (old and new)
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can view org members" ON users;
DROP POLICY IF EXISTS "Org admins can manage org users" ON users;
DROP POLICY IF EXISTS "Super admins can manage all users" ON users;
DROP POLICY IF EXISTS "users_select_own" ON users;
DROP POLICY IF EXISTS "users_select_same_org" ON users;
DROP POLICY IF EXISTS "users_insert_own" ON users;
DROP POLICY IF EXISTS "users_update_own" ON users;
DROP POLICY IF EXISTS "org_admin_users_insert" ON users;
DROP POLICY IF EXISTS "org_admin_users_update" ON users;
DROP POLICY IF EXISTS "org_admin_users_delete" ON users;
DROP POLICY IF EXISTS "super_admin_select_all_users" ON users;
DROP POLICY IF EXISTS "super_admin_update_all_users" ON users;
DROP POLICY IF EXISTS "super_admin_delete_all_users" ON users;
DROP POLICY IF EXISTS "super_admin_insert_any_user" ON users;
DROP POLICY IF EXISTS "self_insert_initial_profile" ON users;
DROP POLICY IF EXISTS "self_update_own_profile" ON users;
DROP POLICY IF EXISTS "service_role_all" ON users;
DROP POLICY IF EXISTS "Allow authenticated to read users" ON users;
DROP POLICY IF EXISTS "Users can view users in same org" ON users;
DROP POLICY IF EXISTS "users_self_select" ON users;
DROP POLICY IF EXISTS "users_org_select" ON users;

-- Catch-all: drop any remaining policies by querying system catalogs
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'users' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON users', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 2: CREATE SIMPLE, NON-RECURSIVE POLICIES
-- ============================================================================

-- Policy 1: Users can SELECT their own row (using auth.uid() directly)
CREATE POLICY "users_select_self"
ON users
FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

-- Policy 2: Super admin can SELECT all users (uses users_internal)
CREATE POLICY "users_select_super_admin"
ON users
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
      AND role = 'super_admin'
  )
);

-- Policy 3: Org admin can SELECT users in same organization (uses users_internal)
CREATE POLICY "users_select_org_admin"
ON users
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'org_admin'
      AND me.organization_id = users.organization_id
      AND me.organization_id IS NOT NULL
  )
);

-- Policy 4: Users can INSERT their own initial profile
CREATE POLICY "users_insert_self"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
  -- Can only insert a row for yourself
  auth_user_id = auth.uid()
);

-- Policy 5: Super admin can INSERT any user
CREATE POLICY "users_insert_super_admin"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
      AND role = 'super_admin'
  )
);

-- Policy 6: Org admin can INSERT users in their organization
CREATE POLICY "users_insert_org_admin"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'org_admin'
      AND me.organization_id = organization_id
      AND me.organization_id IS NOT NULL
  )
);

-- Policy 7: Users can UPDATE their own row
CREATE POLICY "users_update_self"
ON users
FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- Policy 8: Super admin can UPDATE any user
CREATE POLICY "users_update_super_admin"
ON users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
      AND role = 'super_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
      AND role = 'super_admin'
  )
);

-- Policy 9: Org admin can UPDATE users in their organization
CREATE POLICY "users_update_org_admin"
ON users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'org_admin'
      AND me.organization_id = users.organization_id
      AND me.organization_id IS NOT NULL
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'org_admin'
      AND me.organization_id = organization_id
      AND me.organization_id IS NOT NULL
  )
);

-- Policy 10: Super admin can DELETE any user
CREATE POLICY "users_delete_super_admin"
ON users
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
      AND role = 'super_admin'
  )
);

-- Policy 11: Org admin can DELETE users in their organization
CREATE POLICY "users_delete_org_admin"
ON users
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'org_admin'
      AND me.organization_id = users.organization_id
      AND me.organization_id IS NOT NULL
  )
);

-- ============================================================================
-- STEP 3: Verify RLS is enabled
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 4: Create a function to check if admin exists (for seeding)
-- ============================================================================

CREATE OR REPLACE FUNCTION check_user_exists_by_email(user_email TEXT)
RETURNS TABLE(user_id UUID, exists_in_users BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    au.id as user_id,
    EXISTS(SELECT 1 FROM users u WHERE u.auth_user_id = au.id) as exists_in_users
  FROM auth.users au
  WHERE au.email = user_email;
END;
$$;

-- ============================================================================
-- Success message
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '============================================================';
  RAISE NOTICE '✅ COMPLETE USERS RLS FIX APPLIED SUCCESSFULLY';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Policies created:';
  RAISE NOTICE '   SELECT: users_select_self, users_select_super_admin, users_select_org_admin';
  RAISE NOTICE '   INSERT: users_insert_self, users_insert_super_admin, users_insert_org_admin';
  RAISE NOTICE '   UPDATE: users_update_self, users_update_super_admin, users_update_org_admin';
  RAISE NOTICE '   DELETE: users_delete_super_admin, users_delete_org_admin';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 All policies use users_internal view to avoid recursion';
  RAISE NOTICE '🔒 RLS is enabled and forced on users table';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 Users can now:';
  RAISE NOTICE '   - View/update their own profile';
  RAISE NOTICE '   - Create their initial profile after signup';
  RAISE NOTICE '   - Super admin: manage ALL users';
  RAISE NOTICE '   - Org admin: manage users in their organization';
  RAISE NOTICE '============================================================';
END $$;
