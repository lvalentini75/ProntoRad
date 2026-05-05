-- Fix RLS policies for standard_tariffs table
-- Drop existing policies first, then recreate them correctly

-- Drop all existing policies
DROP POLICY IF EXISTS "authenticated_read_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_full_access_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_write_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_update_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_delete_standard_tariffs" ON public.standard_tariffs;

-- Recreate policies with correct structure

-- All authenticated users can read standard tariffs
CREATE POLICY "authenticated_read_standard_tariffs"
ON public.standard_tariffs
FOR SELECT
TO authenticated
USING (true);

-- Super admins can insert
CREATE POLICY "super_admins_insert_standard_tariffs"
ON public.standard_tariffs
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
);

-- Super admins can update
CREATE POLICY "super_admins_update_standard_tariffs"
ON public.standard_tariffs
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
);

-- Super admins can delete
CREATE POLICY "super_admins_delete_standard_tariffs"
ON public.standard_tariffs
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
);
