-- ============================================================================
-- DEFINITIVE FIX: USERS TABLE RLS - BYPASS ALL RECURSION
-- ============================================================================
-- This migration uses SECURITY DEFINER functions to completely bypass RLS
-- for admin operations, eliminating any possibility of recursion.
-- ============================================================================

-- ============================================================================
-- STEP 0: Disable RLS temporarily for cleanup
-- ============================================================================
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 1: DROP ALL EXISTING POLICIES (aggressive)
-- ============================================================================
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'users' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.users', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- ============================================================================
-- STEP 2: Create helper function to get user role WITHOUT triggering RLS
-- This uses a direct table query with SECURITY DEFINER
-- ============================================================================
DROP FUNCTION IF EXISTS get_my_role();
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

-- ============================================================================
-- STEP 3: Create helper function to get user organization_id WITHOUT triggering RLS
-- ============================================================================
DROP FUNCTION IF EXISTS get_my_organization_id();
CREATE OR REPLACE FUNCTION get_my_organization_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT organization_id FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

-- ============================================================================
-- STEP 4: Create SECURITY DEFINER function to insert user (bypasses RLS completely)
-- ============================================================================
DROP FUNCTION IF EXISTS admin_create_user_profile(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
CREATE OR REPLACE FUNCTION admin_create_user_profile(
  p_auth_user_id UUID,
  p_email TEXT,
  p_first_name TEXT,
  p_last_name TEXT,
  p_role TEXT DEFAULT 'end_user',
  p_phone_number TEXT DEFAULT NULL,
  p_fiscal_code TEXT DEFAULT NULL,
  p_organization_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_user_id UUID;
BEGIN
  -- Check if user already exists
  SELECT id INTO new_user_id FROM users WHERE auth_user_id = p_auth_user_id;
  
  IF new_user_id IS NOT NULL THEN
    RAISE NOTICE 'User already exists with id: %', new_user_id;
    RETURN new_user_id;
  END IF;
  
  -- Insert new user
  INSERT INTO users (
    auth_user_id, 
    email, 
    first_name, 
    last_name, 
    role, 
    phone_number, 
    fiscal_code, 
    organization_id,
    created_at, 
    updated_at
  ) VALUES (
    p_auth_user_id,
    p_email,
    p_first_name,
    p_last_name,
    p_role,
    p_phone_number,
    p_fiscal_code,
    p_organization_id,
    NOW(),
    NOW()
  )
  RETURNING id INTO new_user_id;
  
  RAISE NOTICE 'Created user with id: %', new_user_id;
  RETURN new_user_id;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION admin_create_user_profile TO authenticated;

-- ============================================================================
-- STEP 5: Create function to check if user exists (SECURITY DEFINER)
-- ============================================================================
DROP FUNCTION IF EXISTS check_user_exists_by_email(TEXT);
CREATE OR REPLACE FUNCTION check_user_exists_by_email(user_email TEXT)
RETURNS TABLE(user_id UUID, auth_id UUID, exists_in_users BOOLEAN, user_role TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id as user_id,
    au.id as auth_id,
    (u.id IS NOT NULL) as exists_in_users,
    u.role as user_role
  FROM auth.users au
  LEFT JOIN users u ON u.auth_user_id = au.id
  WHERE au.email = user_email;
END;
$$;

GRANT EXECUTE ON FUNCTION check_user_exists_by_email TO authenticated;

-- ============================================================================
-- STEP 6: Create function to get user profile (SECURITY DEFINER)
-- ============================================================================
DROP FUNCTION IF EXISTS get_user_profile_by_auth_id(UUID);
CREATE OR REPLACE FUNCTION get_user_profile_by_auth_id(p_auth_user_id UUID)
RETURNS TABLE(
  id UUID,
  auth_user_id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  phone_number TEXT,
  fiscal_code TEXT,
  organization_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.auth_user_id,
    u.email,
    u.first_name,
    u.last_name,
    u.role,
    u.phone_number,
    u.fiscal_code,
    u.organization_id,
    u.created_at,
    u.updated_at
  FROM users u
  WHERE u.auth_user_id = p_auth_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_profile_by_auth_id TO authenticated;

-- ============================================================================
-- STEP 7: Re-enable RLS with SIMPLE policies (no subqueries on users table!)
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;

-- Policy 1: SELECT own profile (simple, no recursion)
CREATE POLICY "select_own_profile"
ON users FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

-- Policy 2: SELECT all if super_admin (uses helper function)
CREATE POLICY "select_all_if_super_admin"
ON users FOR SELECT
TO authenticated
USING (get_my_role() = 'super_admin');

-- Policy 3: SELECT org members if org_admin (uses helper functions)
CREATE POLICY "select_org_members_if_org_admin"
ON users FOR SELECT
TO authenticated
USING (
  get_my_role() = 'org_admin' 
  AND organization_id = get_my_organization_id()
  AND get_my_organization_id() IS NOT NULL
);

-- Policy 4: INSERT own profile (for initial signup)
CREATE POLICY "insert_own_profile"
ON users FOR INSERT
TO authenticated
WITH CHECK (auth_user_id = auth.uid());

-- Policy 5: INSERT any if super_admin
CREATE POLICY "insert_any_if_super_admin"
ON users FOR INSERT
TO authenticated
WITH CHECK (get_my_role() = 'super_admin');

-- Policy 6: INSERT org members if org_admin
CREATE POLICY "insert_org_members_if_org_admin"
ON users FOR INSERT
TO authenticated
WITH CHECK (
  get_my_role() = 'org_admin'
  AND organization_id = get_my_organization_id()
  AND get_my_organization_id() IS NOT NULL
);

-- Policy 7: UPDATE own profile
CREATE POLICY "update_own_profile"
ON users FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- Policy 8: UPDATE any if super_admin
CREATE POLICY "update_any_if_super_admin"
ON users FOR UPDATE
TO authenticated
USING (get_my_role() = 'super_admin')
WITH CHECK (get_my_role() = 'super_admin');

-- Policy 9: UPDATE org members if org_admin
CREATE POLICY "update_org_members_if_org_admin"
ON users FOR UPDATE
TO authenticated
USING (
  get_my_role() = 'org_admin'
  AND organization_id = get_my_organization_id()
  AND get_my_organization_id() IS NOT NULL
)
WITH CHECK (
  get_my_role() = 'org_admin'
  AND organization_id = get_my_organization_id()
  AND get_my_organization_id() IS NOT NULL
);

-- Policy 10: DELETE any if super_admin
CREATE POLICY "delete_any_if_super_admin"
ON users FOR DELETE
TO authenticated
USING (get_my_role() = 'super_admin');

-- Policy 11: DELETE org members if org_admin
CREATE POLICY "delete_org_members_if_org_admin"
ON users FOR DELETE
TO authenticated
USING (
  get_my_role() = 'org_admin'
  AND organization_id = get_my_organization_id()
  AND get_my_organization_id() IS NOT NULL
);

-- ============================================================================
-- STEP 8: Seed the admin user directly (bypassing RLS since we're in migration)
-- ============================================================================
DO $$
DECLARE
  v_auth_id UUID;
  v_existing_user UUID;
BEGIN
  -- Find auth user
  SELECT id INTO v_auth_id FROM auth.users WHERE email = 'admin@prontorad.demo';
  
  IF v_auth_id IS NULL THEN
    RAISE NOTICE 'Admin auth user not found - skipping seed';
    RETURN;
  END IF;
  
  -- Check if already exists in users table
  SELECT id INTO v_existing_user FROM users WHERE auth_user_id = v_auth_id;
  
  IF v_existing_user IS NOT NULL THEN
    RAISE NOTICE 'Admin user already exists in users table: %', v_existing_user;
    RETURN;
  END IF;
  
  -- Insert admin user
  INSERT INTO users (
    auth_user_id,
    email,
    first_name,
    last_name,
    role,
    phone_number,
    fiscal_code,
    created_at,
    updated_at
  ) VALUES (
    v_auth_id,
    'admin@prontorad.demo',
    'Admin',
    'ProntoRad',
    'super_admin',
    '+39 333 1234567',
    'ADMPRN80A01H501Z',
    NOW(),
    NOW()
  );
  
  RAISE NOTICE '✅ Admin user seeded successfully!';
END $$;

-- ============================================================================
-- Success message
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '✅ DEFINITIVE USERS RLS FIX APPLIED SUCCESSFULLY';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';
  RAISE NOTICE '🔧 Key changes:';
  RAISE NOTICE '   - All policies use SECURITY DEFINER helper functions';
  RAISE NOTICE '   - get_my_role() - returns current user role';
  RAISE NOTICE '   - get_my_organization_id() - returns current user org';
  RAISE NOTICE '   - admin_create_user_profile() - creates user bypassing RLS';
  RAISE NOTICE '   - check_user_exists_by_email() - checks user existence';
  RAISE NOTICE '   - get_user_profile_by_auth_id() - gets profile safely';
  RAISE NOTICE '';
  RAISE NOTICE '🔒 11 RLS policies created (no recursion possible)';
  RAISE NOTICE '🌱 Admin user seeded if auth user exists';
  RAISE NOTICE '============================================================';
END $$;
