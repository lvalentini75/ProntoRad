-- Migration to add missing columns to users table: role, organization_id
-- This fixes the error: "Could not find the 'role' column of 'users' in the schema cache"

-- 1) Add role column if missing (defaults to 'end_user')
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS role text DEFAULT 'end_user';

-- 2) Add organization_id column if missing
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS organization_id uuid NULL;

-- 3) Create organizations table if not exists (needed for FK)
CREATE TABLE IF NOT EXISTS public.organizations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  org_type text DEFAULT 'hospital',
  address text,
  city text,
  province text,
  region text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 4) Enable RLS on organizations
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- 5) Add policy for organizations (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'organizations' AND policyname = 'organizations_auth_all'
  ) THEN
    CREATE POLICY organizations_auth_all ON public.organizations
      FOR ALL TO authenticated
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;

-- 6) Add FK from users.organization_id to organizations.id (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_organization_id_fkey'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_organization_id_fkey
      FOREIGN KEY (organization_id)
      REFERENCES public.organizations(id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- 7) Create index on users.role for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);

-- 8) Create index on users.organization_id
CREATE INDEX IF NOT EXISTS idx_users_organization_id ON public.users(organization_id);
