-- ============================================================================
-- Add missing columns to users table
-- ============================================================================
-- Problem: Current users table is missing role, organization_id, auth_user_id, 
--          fiscal_code, and date_of_birth columns
-- Solution: Add these columns with appropriate defaults and constraints
-- ============================================================================

-- Add auth_user_id column (link to auth.users table)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'auth_user_id'
  ) THEN
    ALTER TABLE users ADD COLUMN auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
  END IF;
END $$;

-- Add role column (super_admin, org_admin, end_user)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'role'
  ) THEN
    ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'end_user' CHECK (role IN ('super_admin', 'org_admin', 'end_user'));
    CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
  END IF;
END $$;

-- Add organization_id column
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE users ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_users_organization_id ON users(organization_id);
  END IF;
END $$;

-- Add fiscal_code column (Italian tax code)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'fiscal_code'
  ) THEN
    ALTER TABLE users ADD COLUMN fiscal_code TEXT;
  END IF;
END $$;

-- Add date_of_birth column
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'date_of_birth'
  ) THEN
    ALTER TABLE users ADD COLUMN date_of_birth DATE;
  END IF;
END $$;

-- ============================================================================
-- Success message
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Users table schema updated';
  RAISE NOTICE '   - auth_user_id (UUID, FK to auth.users) ✓';
  RAISE NOTICE '   - role (TEXT, default: end_user) ✓';
  RAISE NOTICE '   - organization_id (UUID, FK to organizations) ✓';
  RAISE NOTICE '   - fiscal_code (TEXT) ✓';
  RAISE NOTICE '   - date_of_birth (DATE) ✓';
END $$;
