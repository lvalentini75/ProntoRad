-- Fix exam_types RLS policies to allow reading by all authenticated users
-- This is necessary for joins in booking queries

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Anyone can view exam types" ON exam_types;
DROP POLICY IF EXISTS "Authenticated users can view exam types" ON exam_types;

-- Create a simple policy that allows all authenticated users to read exam types
CREATE POLICY "Authenticated users can view exam types"
ON exam_types
FOR SELECT
TO authenticated
USING (true);

-- Also allow anonymous users to view exam types (for public booking forms)
CREATE POLICY "Anonymous users can view exam types"
ON exam_types
FOR SELECT
TO anon
USING (true);

-- Ensure only admins can modify exam types
DROP POLICY IF EXISTS "Only super admins can modify exam types" ON exam_types;
CREATE POLICY "Only super admins can modify exam types"
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
