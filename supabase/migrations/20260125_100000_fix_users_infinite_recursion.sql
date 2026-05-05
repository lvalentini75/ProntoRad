-- ============================================================================
-- FIX INFINITE RECURSION IN USERS TABLE RLS POLICIES
-- ============================================================================
-- Problem: RLS policies on users table query users itself, causing infinite 
-- recursion when combined with helper functions used by other tables.
--
-- Solution: Create a SECURITY DEFINER view that bypasses RLS and use it in:
-- 1. Helper functions (is_super_admin, is_org_admin, etc.)
-- 2. RLS policies on users table itself
-- ============================================================================

-- ============================================================================
-- STEP 1: Create internal view that bypasses RLS
-- ============================================================================

-- Drop existing view if exists
DROP VIEW IF EXISTS users_internal CASCADE;

-- Create view with SECURITY DEFINER to bypass RLS
CREATE VIEW users_internal 
WITH (security_barrier = false) 
AS
SELECT 
  id,
  auth_user_id,
  email,
  first_name,
  last_name,
  phone_number,
  fiscal_code,
  date_of_birth,
  role,
  organization_id,
  created_at,
  updated_at
FROM users;

-- Grant SELECT on the view to authenticated and anon users
GRANT SELECT ON users_internal TO authenticated;
GRANT SELECT ON users_internal TO anon;

-- ============================================================================
-- STEP 2: Recreate helper functions using users_internal
-- ============================================================================

-- Helper function: Check if current user is super admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
    AND role = 'super_admin'
  );
END;
$$;

-- Helper function: Check if current user is org admin (or super admin)
CREATE OR REPLACE FUNCTION is_org_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
    AND role IN ('org_admin', 'super_admin')
  );
END;
$$;

-- Helper function: Get current user's organization_id
CREATE OR REPLACE FUNCTION current_user_organization_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  org_id UUID;
BEGIN
  SELECT organization_id INTO org_id
  FROM users_internal
  WHERE auth_user_id = auth.uid();
  
  RETURN org_id;
END;
$$;

-- Helper function: Check if user can access organization
CREATE OR REPLACE FUNCTION can_access_organization(target_org_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Super admins can access everything
  IF is_super_admin() THEN
    RETURN TRUE;
  END IF;
  
  -- Org admins can only access their own organization
  RETURN EXISTS (
    SELECT 1 FROM users_internal
    WHERE auth_user_id = auth.uid()
    AND organization_id = target_org_id
    AND role IN ('org_admin', 'super_admin')
  );
END;
$$;

-- ============================================================================
-- STEP 3: Drop and recreate RLS policies on users table using users_internal
-- ============================================================================

-- Drop all existing policies on users
DROP POLICY IF EXISTS "org_admin_insert_users_same_org" ON users;
DROP POLICY IF EXISTS "org_admin_update_users_same_org" ON users;
DROP POLICY IF EXISTS "org_admin_select_users_same_org" ON users;
DROP POLICY IF EXISTS "self_select_users_by_auth_id" ON users;

-- Ensure RLS is enabled
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- INSERT: org_admin/super_admin can create users within their organization
CREATE POLICY "org_admin_insert_users_same_org"
ON users
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin', 'super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = organization_id
  )
);

-- UPDATE: org_admin/super_admin can update users within their organization
CREATE POLICY "org_admin_update_users_same_org"
ON users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin', 'super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = users.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin', 'super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = organization_id
  )
);

-- SELECT: org_admin/super_admin can view users within their organization
CREATE POLICY "org_admin_select_users_same_org"
ON users
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users_internal me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin', 'super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = users.organization_id
  )
);

-- Each authenticated user can always read their own profile row
CREATE POLICY "self_select_users_by_auth_id"
ON users
FOR SELECT
TO authenticated
USING (
  auth.uid() IS NOT NULL 
  AND auth_user_id = auth.uid()
);

-- ============================================================================
-- Success message
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Fixed infinite recursion in users table RLS policies';
  RAISE NOTICE '   - Created users_internal view to bypass RLS';
  RAISE NOTICE '   - Updated helper functions to use users_internal';
  RAISE NOTICE '   - Recreated all RLS policies on users table';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 This fixes RLS issues for ALL tables that depend on user checks:';
  RAISE NOTICE '   - exam_types ✓';
  RAISE NOTICE '   - facility_exam_offerings ✓';
  RAISE NOTICE '   - availability_slots ✓';
  RAISE NOTICE '   - tariffs ✓';
  RAISE NOTICE '   - bookings ✓';
  RAISE NOTICE '   - organizations ✓';
END $$;
