-- Diagnose and fix exam_types RLS policies
-- This ensures all users can read exam_types while maintaining security for writes

-- Step 1: Drop ALL existing policies on exam_types to start fresh
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'exam_types' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON exam_types', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- Step 2: Enable RLS on exam_types
ALTER TABLE exam_types ENABLE ROW LEVEL SECURITY;

-- Step 3: Create comprehensive SELECT policy for everyone
-- This allows both authenticated and anonymous users to read all exam types
CREATE POLICY "Anyone can view exam types"
ON exam_types
FOR SELECT
USING (true);

-- Step 4: Allow super_admin to do everything
CREATE POLICY "Super admins full access to exam types"
ON exam_types
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.role = 'super_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.role = 'super_admin'
  )
);

-- Step 5: Verify policies were created
DO $$
DECLARE
    policy_count integer;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'exam_types' AND schemaname = 'public';
    
    RAISE NOTICE 'Total policies on exam_types: %', policy_count;
    
    IF policy_count < 2 THEN
        RAISE WARNING 'Expected at least 2 policies on exam_types, but found %', policy_count;
    END IF;
END $$;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ exam_types RLS policies fixed';
  RAISE NOTICE '   - Anyone can read exam_types';
  RAISE NOTICE '   - Only super_admin can modify exam_types';
END $$;
