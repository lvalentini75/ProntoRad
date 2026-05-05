-- Users table RLS policies for manual booking (patients creation/update)
-- This migration enables org_admin and super_admin users to INSERT and UPDATE
-- rows in public.users that belong to their same organization. It also
-- relaxes SELECT for org admins on their organization, in case it was missing.

-- Safety: wrap each policy creation in a DO block to avoid duplicate errors

-- Ensure RLS is enabled on users (no-op if already enabled)
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

-- Helper condition used in policies
-- We inline the condition in each policy to avoid dependency on custom functions.

-- INSERT policy: org_admin/super_admin can create users within their org
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'org_admin_insert_users_same_org'
  ) THEN
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
  END IF;
END $$;

-- UPDATE policy: org_admin/super_admin can update users within their org
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'org_admin_update_users_same_org'
  ) THEN
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
  END IF;
END $$;

-- SELECT policy: org_admin/super_admin can see users within their org
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'org_admin_select_users_same_org'
  ) THEN
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
          AND me.organization_id = users.organization_id
      )
    );
  END IF;
END $$;

-- OPTIONAL: ensure each authenticated user can always select their own profile row
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
