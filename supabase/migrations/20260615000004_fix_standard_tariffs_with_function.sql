-- Fix standard_tariffs RLS policies using SECURITY DEFINER function
-- This avoids RLS recursion issues when checking user role

-- First, create a helper function to check if user is admin
-- SECURITY DEFINER allows bypassing RLS when checking user role
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
        AND role IN ('super_admin', 'org_admin')
    );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;

-- Drop all existing policies on standard_tariffs
DROP POLICY IF EXISTS "authenticated_read_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "admins_insert_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "admins_update_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "admins_delete_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_insert_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_update_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_delete_standard_tariffs" ON public.standard_tariffs;

-- Recreate policies using the helper function

-- All authenticated users can read standard tariffs
CREATE POLICY "standard_tariffs_select"
ON public.standard_tariffs
FOR SELECT
TO authenticated
USING (true);

-- Admins can insert using the helper function
CREATE POLICY "standard_tariffs_insert"
ON public.standard_tariffs
FOR INSERT
TO authenticated
WITH CHECK (public.is_admin_user());

-- Admins can update using the helper function
CREATE POLICY "standard_tariffs_update"
ON public.standard_tariffs
FOR UPDATE
TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- Admins can delete using the helper function
CREATE POLICY "standard_tariffs_delete"
ON public.standard_tariffs
FOR DELETE
TO authenticated
USING (public.is_admin_user());
