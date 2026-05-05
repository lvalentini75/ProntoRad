-- Migration: Fix tariffs table RLS policies
-- Problem: Insert operations on tariffs fail with RLS violation
-- Solution: Add proper RLS policies for org_admin users to manage tariffs

-- 1. Ensure tariffs table exists (should already exist, but let's be safe)
CREATE TABLE IF NOT EXISTS public.tariffs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  exam_type_id uuid NOT NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
  price numeric(10,2) NOT NULL DEFAULT 0,
  currency text DEFAULT 'EUR',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, exam_type_id)
);

-- 2. Enable RLS (idempotent)
ALTER TABLE public.tariffs ENABLE ROW LEVEL SECURITY;

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tariffs_org ON public.tariffs(organization_id);
CREATE INDEX IF NOT EXISTS idx_tariffs_exam ON public.tariffs(exam_type_id);

-- 4. Drop existing policies if any (to avoid duplicates)
DROP POLICY IF EXISTS tariffs_read_all ON public.tariffs;
DROP POLICY IF EXISTS tariffs_select_public ON public.tariffs;
DROP POLICY IF EXISTS tariffs_insert_org_admin ON public.tariffs;
DROP POLICY IF EXISTS tariffs_update_org_admin ON public.tariffs;
DROP POLICY IF EXISTS tariffs_delete_org_admin ON public.tariffs;
DROP POLICY IF EXISTS tariffs_all_org_admin ON public.tariffs;
DROP POLICY IF EXISTS tariffs_auth_all ON public.tariffs;

-- 5. Policy: Everyone (including anon) can READ tariffs
CREATE POLICY tariffs_select_public ON public.tariffs
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- 6. Policy: Authenticated users who are org_admin can INSERT tariffs for their organization
CREATE POLICY tariffs_insert_org_admin ON public.tariffs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_user_id = auth.uid()
        AND u.role = 'org_admin'
        AND u.organization_id = tariffs.organization_id
    )
  );

-- 7. Policy: Authenticated users who are org_admin can UPDATE tariffs for their organization
CREATE POLICY tariffs_update_org_admin ON public.tariffs
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_user_id = auth.uid()
        AND u.role = 'org_admin'
        AND u.organization_id = tariffs.organization_id
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_user_id = auth.uid()
        AND u.role = 'org_admin'
        AND u.organization_id = tariffs.organization_id
    )
  );

-- 8. Policy: Authenticated users who are org_admin can DELETE tariffs for their organization
CREATE POLICY tariffs_delete_org_admin ON public.tariffs
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_user_id = auth.uid()
        AND u.role = 'org_admin'
        AND u.organization_id = tariffs.organization_id
    )
  );

-- 9. Policy: Super admins can do everything
CREATE POLICY tariffs_super_admin_all ON public.tariffs
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_user_id = auth.uid()
        AND u.role = 'super_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_user_id = auth.uid()
        AND u.role = 'super_admin'
    )
  );
