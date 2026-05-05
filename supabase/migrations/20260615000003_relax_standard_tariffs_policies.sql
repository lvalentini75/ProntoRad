-- Relax RLS policies for standard_tariffs to allow org_admin and super_admin
-- Drop existing policies first, then recreate with less restrictive rules

DROP POLICY IF EXISTS "authenticated_read_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_insert_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_update_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_delete_standard_tariffs" ON public.standard_tariffs;

-- All authenticated users can read standard tariffs
CREATE POLICY "authenticated_read_standard_tariffs"
ON public.standard_tariffs
FOR SELECT
TO authenticated
USING (true);

-- Super admins and org admins can insert
CREATE POLICY "admins_insert_standard_tariffs"
ON public.standard_tariffs
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role IN ('super_admin', 'org_admin')
    )
);

-- Super admins and org admins can update
CREATE POLICY "admins_update_standard_tariffs"
ON public.standard_tariffs
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role IN ('super_admin', 'org_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role IN ('super_admin', 'org_admin')
    )
);

-- Super admins and org admins can delete
CREATE POLICY "admins_delete_standard_tariffs"
ON public.standard_tariffs
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role IN ('super_admin', 'org_admin')
    )
);
