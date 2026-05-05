-- ============================================================================
-- ALLOW SELF-INSERT AND SUPER ADMIN INSERT FOR USERS TABLE
-- ============================================================================
-- Problem: The current INSERT policy requires the inserting user to already
--          have an organization_id in the users table. But if a user doesn't
--          exist yet in the users table, they can't insert their own profile!
--
-- Solution: 
-- 1. Add a policy that allows authenticated users to insert their OWN initial profile
-- 2. Add a policy that allows super_admin to insert users in any organization
-- ============================================================================

-- ============================================================================
-- STEP 1: Allow self-insert for initial profile creation
-- ============================================================================

-- First, let's see if policy already exists and drop it
DROP POLICY IF EXISTS "self_insert_initial_profile" ON users;

-- CREATE: Allow authenticated user to create their own profile (self-registration)
CREATE POLICY "self_insert_initial_profile"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
  -- The user can only insert a record for themselves
  auth_user_id = auth.uid()
  -- And no record exists yet for this user
  AND NOT EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
  )
);

-- ============================================================================
-- STEP 2: Allow super_admin to insert users in any organization
-- ============================================================================

-- Drop existing if exists
DROP POLICY IF EXISTS "super_admin_insert_any_user" ON users;

-- CREATE: Super admin can create users in ANY organization (or without org)
CREATE POLICY "super_admin_insert_any_user"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
);

-- ============================================================================
-- STEP 3: Also allow users to update their OWN profile
-- ============================================================================

DROP POLICY IF EXISTS "self_update_own_profile" ON users;

CREATE POLICY "self_update_own_profile"
ON users
FOR UPDATE
TO authenticated
USING (
  auth_user_id = auth.uid()
)
WITH CHECK (
  auth_user_id = auth.uid()
  -- Prevent user from changing their own role
  AND role = (SELECT role FROM users_internal WHERE auth_user_id = auth.uid())
);

-- ============================================================================
-- Success message
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Added INSERT policies for users table';
  RAISE NOTICE '   - self_insert_initial_profile: allows self-registration';
  RAISE NOTICE '   - super_admin_insert_any_user: super_admin can create any user';
  RAISE NOTICE '   - self_update_own_profile: users can update own profile';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 Now users can:';
  RAISE NOTICE '   - Create their own initial profile after Supabase auth signup';
  RAISE NOTICE '   - Super admin can create users in any organization';
  RAISE NOTICE '   - Users can update their own profile (except role)';
END $$;
