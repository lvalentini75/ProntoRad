-- ============================================================================
-- FIX SUPER ADMIN INFINITE RECURSION IN RLS POLICIES
-- ============================================================================
-- Problem: The super_admin policies added in 20260127_000000 query the users
--          table directly, causing infinite recursion when checking permissions.
--
-- Solution: Update all super_admin policies to use users_internal view instead
--           of querying users table directly.
-- ============================================================================

-- Drop existing super_admin policies
DROP POLICY IF EXISTS "super_admin_select_all_users" ON users;
DROP POLICY IF EXISTS "super_admin_update_all_users" ON users;
DROP POLICY IF EXISTS "super_admin_delete_all_users" ON users;

-- ============================================================================
-- STEP 1: Recreate SELECT policy using users_internal
-- ============================================================================

-- CREATE: Super admin can view ALL users in the system
CREATE POLICY "super_admin_select_all_users"
ON users
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
);

-- ============================================================================
-- STEP 2: Recreate UPDATE policy using users_internal
-- ============================================================================

-- Super admin can update ALL users
CREATE POLICY "super_admin_update_all_users"
ON users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
);

-- ============================================================================
-- STEP 3: Recreate DELETE policy using users_internal
-- ============================================================================

-- Super admin can delete ALL users
CREATE POLICY "super_admin_delete_all_users"
ON users
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
);

-- ============================================================================
-- Success message
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Fixed super_admin infinite recursion in users table';
  RAISE NOTICE '   - All super_admin policies now use users_internal view';
  RAISE NOTICE '   - super_admin_select_all_users ✓';
  RAISE NOTICE '   - super_admin_update_all_users ✓';
  RAISE NOTICE '   - super_admin_delete_all_users ✓';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 Super admin should now be able to:';
  RAISE NOTICE '   - View ALL users in the system';
  RAISE NOTICE '   - Update ANY user';
  RAISE NOTICE '   - Delete ANY user';
  RAISE NOTICE '   - WITHOUT triggering infinite recursion';
END $$;
