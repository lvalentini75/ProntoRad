-- ============================================================================
-- SUPER ADMIN: Allow selecting ALL users in the system
-- ============================================================================
-- Problem: Current RLS policies only allow org_admin to see users in their org.
-- Super admin (organization_id = NULL) cannot see any users except themselves.
--
-- Solution: Add explicit policy for super_admin to SELECT all users
-- ============================================================================

-- Drop existing super_admin policy if exists
DROP POLICY IF EXISTS "super_admin_select_all_users" ON users;

-- CREATE: Super admin can view ALL users in the system
CREATE POLICY "super_admin_select_all_users"
ON users
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
);

-- Also add UPDATE, DELETE policies for super_admin
DROP POLICY IF EXISTS "super_admin_update_all_users" ON users;
DROP POLICY IF EXISTS "super_admin_delete_all_users" ON users;

-- Super admin can update ALL users
CREATE POLICY "super_admin_update_all_users"
ON users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
);

-- Super admin can delete ALL users
CREATE POLICY "super_admin_delete_all_users"
ON users
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role = 'super_admin'
  )
);

-- ============================================================================
-- Success message
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Super admin can now SELECT/UPDATE/DELETE all users';
  RAISE NOTICE '   - super_admin_select_all_users ✓';
  RAISE NOTICE '   - super_admin_update_all_users ✓';
  RAISE NOTICE '   - super_admin_delete_all_users ✓';
END $$;
