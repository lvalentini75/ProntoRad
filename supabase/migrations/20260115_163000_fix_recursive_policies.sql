-- Fix infinite recursion in RLS policies
-- The previous policies caused infinite recursion because they query the users table
-- from within the users table policy check. This migration uses a different approach:
-- 1. Use auth.jwt() to extract custom claims (if set)
-- 2. Or use a security definer function to break the recursion
-- 3. Or simply allow authenticated users to read/write based on simpler rules

-- Drop all existing problematic policies on users table
DROP POLICY IF EXISTS org_admin_insert_users_same_org ON public.users;
DROP POLICY IF EXISTS org_admin_update_users_same_org ON public.users;
DROP POLICY IF EXISTS org_admin_select_users_same_org ON public.users;
DROP POLICY IF EXISTS self_select_users_by_auth_id ON public.users;

-- Create a security definer function that can read users without triggering RLS
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TABLE (
  user_id uuid,
  user_role text,
  org_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT id, role, organization_id
  FROM public.users
  WHERE auth_user_id = auth.uid()
  LIMIT 1;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

-- New policies using the security definer function (no recursion!)

-- SELECT: Users can read their own profile + org admins can read users in their org
CREATE POLICY users_select_policy
ON public.users
FOR SELECT
TO authenticated
USING (
  -- Allow reading own profile
  auth_user_id = auth.uid()
  OR
  -- Allow org_admin/super_admin to read users in their org
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id IS NOT NULL
      AND me.org_id = users.organization_id
  )
);

-- INSERT: org_admin/super_admin can create users in their org
CREATE POLICY users_insert_policy
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id IS NOT NULL
      AND me.org_id = organization_id
  )
);

-- UPDATE: Users can update their own profile + org admins can update users in their org
CREATE POLICY users_update_policy
ON public.users
FOR UPDATE
TO authenticated
USING (
  -- Allow updating own profile
  auth_user_id = auth.uid()
  OR
  -- Allow org_admin/super_admin to update users in their org
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id IS NOT NULL
      AND me.org_id = users.organization_id
  )
)
WITH CHECK (
  -- Same check for the new values
  auth_user_id = auth.uid()
  OR
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id IS NOT NULL
      AND me.org_id = organization_id
  )
);

-- DELETE: Only super_admin can delete users
CREATE POLICY users_delete_policy
ON public.users
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role = 'super_admin'
  )
);

-- Fix tariffs table policies (if they have similar issues)
-- Drop existing policies
DROP POLICY IF EXISTS tariffs_select_policy ON public.tariffs;
DROP POLICY IF EXISTS tariffs_insert_policy ON public.tariffs;
DROP POLICY IF EXISTS tariffs_update_policy ON public.tariffs;
DROP POLICY IF EXISTS tariffs_delete_policy ON public.tariffs;

-- Enable RLS on tariffs
ALTER TABLE public.tariffs ENABLE ROW LEVEL SECURITY;

-- SELECT: org_admin can view tariffs for their organization
CREATE POLICY tariffs_select_policy
ON public.tariffs
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin', 'org_staff')
      AND me.org_id = tariffs.organization_id
  )
);

-- INSERT: org_admin can create tariffs for their organization
CREATE POLICY tariffs_insert_policy
ON public.tariffs
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id = organization_id
  )
);

-- UPDATE: org_admin can update tariffs for their organization
CREATE POLICY tariffs_update_policy
ON public.tariffs
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id = tariffs.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id = organization_id
  )
);

-- DELETE: org_admin can delete tariffs for their organization
CREATE POLICY tariffs_delete_policy
ON public.tariffs
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
      AND me.org_id = tariffs.organization_id
  )
);
