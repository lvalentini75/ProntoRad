-- Fix exam_types infinite recursion error
-- Date: 2026-01-25 00:00:00
-- 
-- Problem: The policy "Super admins full access to exam types" directly queries
-- the users table, causing infinite recursion when RLS checks are performed.
-- 
-- Solution: Use the is_super_admin() SECURITY DEFINER function which bypasses RLS

-- ==============================================================================
-- FIX EXAM_TYPES TABLE POLICIES
-- ==============================================================================

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Anyone can view exam types" ON exam_types;
DROP POLICY IF EXISTS "Super admins full access to exam types" ON exam_types;
DROP POLICY IF EXISTS "Public can view exam types" ON exam_types;
DROP POLICY IF EXISTS "Super admins can manage exam types" ON exam_types;

-- Enable RLS on exam_types
ALTER TABLE exam_types ENABLE ROW LEVEL SECURITY;

-- Allow everyone (authenticated and anonymous) to read exam types
CREATE POLICY "Public can view exam types"
ON exam_types
FOR SELECT
USING (true);

-- Allow super admins to perform all operations (INSERT, UPDATE, DELETE)
-- Using is_super_admin() SECURITY DEFINER function to avoid infinite recursion
CREATE POLICY "Super admins can manage exam types"
ON exam_types
FOR ALL
TO authenticated
USING (is_super_admin())
WITH CHECK (is_super_admin());

-- Verify policies were created
DO $$
DECLARE
    policy_count integer;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'exam_types' AND schemaname = 'public';
    
    RAISE NOTICE '✅ exam_types RLS policies fixed';
    RAISE NOTICE '   Total policies on exam_types: %', policy_count;
    RAISE NOTICE '   - Anyone can read exam_types';
    RAISE NOTICE '   - Only super_admin can modify exam_types (using is_super_admin())';
    RAISE NOTICE '   - No more infinite recursion!';
END $$;
