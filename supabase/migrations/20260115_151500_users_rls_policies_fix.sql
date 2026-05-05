-- Fix RLS policies on public.users for manual booking flow
-- Removes invalid reference to NEW in WITH CHECK and normalizes column references

-- Ensure RLS is enabled (no-op if already enabled)
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

-- Drop previous policies if they exist (in case of partial/failed deploys)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'org_admin_insert_users_same_org'
  ) THEN
    DROP POLICY org_admin_insert_users_same_org ON public.users;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'org_admin_update_users_same_org'
  ) THEN
    DROP POLICY org_admin_update_users_same_org ON public.users;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'org_admin_select_users_same_org'
  ) THEN
    DROP POLICY org_admin_select_users_same_org ON public.users;
  END IF;
END $$;

-- INSERT: org_admin/super_admin can create users within their organization
CREATE POLICY org_admin_insert_users_same_org
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin','super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = organization_id
  )
);

-- UPDATE: org_admin/super_admin can update users within their organization
CREATE POLICY org_admin_update_users_same_org
ON public.users
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin','super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin','super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = organization_id
  )
);

-- SELECT: org_admin/super_admin can view users within their organization
CREATE POLICY org_admin_select_users_same_org
ON public.users
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users me
    WHERE me.auth_user_id = auth.uid()
      AND me.role IN ('org_admin','super_admin')
      AND me.organization_id IS NOT NULL
      AND me.organization_id = organization_id
  )
);

-- Optional helper: each authenticated user can always read their own profile row
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'self_select_users_by_auth_id'
  ) THEN
    CREATE POLICY self_select_users_by_auth_id
    ON public.users
    FOR SELECT
    TO authenticated
    USING (auth.uid() IS NOT NULL AND auth_user_id = auth.uid());
  END IF;
END $$;
